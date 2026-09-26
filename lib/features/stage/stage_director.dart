import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_state.dart';
import '../../game.dart';
import '../anim/frame_anim.dart';
import '../audio/music.dart';
import '../audio/sfx.dart';
import '../characters/maxito/maxito_state.dart';
import '../characters/name_tag.dart';
import '../characters/sebastian/sebastian_character.dart';
import '../events/dialogues.dart';
import '../events/models.dart';
import '../room/room_layout.dart';
import 'shadow.dart';
import '../sleep/sleep.dart';
import '../../ui/minigame_overlay.dart';
import '../tamagotchi/tamagotchi.dart';

/// Who is on screen, what they play and say: runs the HUD actions (animations,
/// music, lines, hearts), lets the two chat between themselves now and then,
/// and keeps the Tamagotchi stats drifting.
class StageDirector extends Component with HasGameReference<DosGatitosGame> {
  StageDirector() : super(priority: 20); // duo scenes, bubbles and hearts above everyone

  /// The characters register themselves here on load.
  static PositionComponent? sebastian;
  static PositionComponent? maxito;

  /// Frame animations currently replacing the idle sprites. While [duoAnim]
  /// plays, both idle characters are hidden and the pair is drawn here.
  static final FramePlayer sebastianAnim = FramePlayer();
  static final FramePlayer maxitoAnim = FramePlayer();
  static final FramePlayer duoAnim = FramePlayer();

  static StageDirector? _instance;
  static StageDirector? get instance => _instance;

  FrameAnimData? _dance;
  FrameAnimData? _record;
  FrameAnimData? _cook;
  FrameAnimData? _toast;
  FrameAnimData? _cushions;
  FrameAnimData? _dinner;
  FrameAnimData? _hug;

  final _rnd = math.Random();
  final List<_Bubble> _bubbles = [];
  final List<_Heart> _hearts = [];
  final NameTag _sebTag = NameTag('Sebastián', accent: const Color(0xFF8EC5FF));
  final NameTag _maxTag = NameTag('Maxito', accent: const Color(0xFFFF9A4D));
  final ui.Paint _duoPaint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  double _clock = 0;
  double _nextChat = 18;
  double _driftAcc = 0;

  @override
  Future<void> onLoad() async {
    _instance = this;
    const seb = 'assets/characters/sebastian/anim';
    const max = 'assets/characters/maxito/anim';
    const duo = 'assets/characters/duo/anim';
    final loaded = await Future.wait([
      FrameAnimData.load(seb, 'dance'),
      FrameAnimData.load(max, 'record'),
      FrameAnimData.load(seb, 'cook'),
      FrameAnimData.load(duo, 'toast'),
      FrameAnimData.load(duo, 'cushions'),
      FrameAnimData.load(duo, 'dinner'),
      FrameAnimData.load(duo, 'hug'),
    ]);
    _dance = loaded[0];
    _record = loaded[1];
    _cook = loaded[2];
    _toast = loaded[3];
    _cushions = loaded[4];
    _dinner = loaded[5];
    _nextChat = 60;
    Sleep.instance.onWake = _goodMorning;
    MiniGame.instance.onClosed = _backFromRoof;
    _playLines(_hello[_rnd.nextInt(_hello.length)], after: 6); // after the splash
    _hug = loaded[6];
  }

  @override
  void onRemove() {
    if (identical(_instance, this)) _instance = null;
    super.onRemove();
  }

  bool get _someoneFocused => Sebastian.isFocused || MaxitoController.instance.state.isCloseUp;
  bool get _busy => sebastianAnim.playing || maxitoAnim.playing || duoAnim.playing || _bubbles.isNotEmpty;

  // ---------------------------------------------------------------------------
  // HUD actions
  // ---------------------------------------------------------------------------

  /// Runs an action: stats (Tamagotchi core) + what the player sees and hears.
  ActionResult? act(TamagotchiAction action, {String? conQuien}) {
    final result = tamagotchi.activar(action, conQuien: conQuien);
    if (wish.value == action) wish.value = null; // they got what they asked for
    _bubbles.clear(); // an action interrupts whatever they were chatting about
    _nextChat = _clock + 30; // an action is a conversation of its own
    switch (action) {
      case TamagotchiAction.ponerMusica:
        _musicTime();
      case TamagotchiAction.servirVino:
        _stopAll();
        final seconds = _playLines(_wineChats[_rnd.nextInt(_wineChats.length)]);
        duoAnim.play(_toast, seconds: seconds + 1.5); // they sip and clink the whole conversation
        _burst(4, delay: 6);
      case TamagotchiAction.hablar:
        _stopAll();
        // a long talk on the cushions: two conversations in a row
        final first = _rnd.nextInt(kJointDialogues.length);
        var second = _rnd.nextInt(kJointDialogues.length - 1);
        if (second >= first) second++;
        var seconds = startChat(dialogue: kJointDialogues[first]);
        seconds = startChat(dialogue: kJointDialogues[second], after: seconds + 1.2);
        duoAnim.play(_cushions, seconds: seconds + 1);
      case TamagotchiAction.darUnAbrazo:
        _stopAll();
        duoAnim.play(_hug);
        _pair(_pick(_hugMax), _pick(_hugSeb), first: LineSpeaker.maxito);
        _burst(9, delay: 5); // when the hug gets tight
      case TamagotchiAction.jugar:
        _pair(_pick(_playMax), _pick(_playSeb), first: LineSpeaker.maxito);
      case TamagotchiAction.cenar:
        _dinnerTime();
      case TamagotchiAction.dormir:
      case TamagotchiAction.preguntar:
        break; // bedtime runs its own scene; «Preguntar» is the HUD's question flow
    }
    return result;
  }

  /// Maxito puts a record on, the dance track starts and Sebastián dances.
  void _musicTime() {
    _stopAll();
    Music.instance.start();
    maxitoAnim.play(_record, onDone: () {
      Music.instance.fadeTo('baile', out: const Duration(milliseconds: 600), fadeIn: const Duration(milliseconds: 900));
      say(LineSpeaker.maxito, _pick(const ['¡Temazo!', 'Esta es para vos, Sebas.', '¡A bailar!']));
      sebastianAnim.play(_dance, seconds: 34, onDone: () => Music.instance.fadeTo('casa'));
    });
  }

  // ---------------------------------------------------------------------------
  // wishes: they ask for what they miss, and the HUD lights that button
  // ---------------------------------------------------------------------------

  double _nextWishCheck = 20;
  double _wishAge = 0;

  void _checkWishes(double dt) {
    if (wish.value != null) {
      _wishAge += dt;
      if (_wishAge > 30) wish.value = null; // they forgot about it
      return;
    }
    if (_clock < _nextWishCheck || _busy || _someoneFocused || Sleep.instance.active) return;
    _nextWishCheck = _clock + 25 + _rnd.nextDouble() * 15;
    ({LineSpeaker who, StatKind kind, double v})? low;
    for (final (who, c) in [(LineSpeaker.sebastian, tamagotchi.sebastian), (LineSpeaker.maxito, tamagotchi.maxito)]) {
      for (final (kind, v) in [(StatKind.energia, c.energia), (StatKind.animo, c.animo), (StatKind.carino, c.carino), (StatKind.social, c.social)]) {
        if (v < 55 && (low == null || v < low.v)) low = (who: who, kind: kind, v: v);
      }
    }
    if (low == null) return;
    final night = DateTime.now().hour >= 22 || DateTime.now().hour < 7;
    final action = switch (low.kind) {
      StatKind.energia => night ? TamagotchiAction.dormir : TamagotchiAction.cenar,
      StatKind.animo => TamagotchiAction.ponerMusica,
      StatKind.carino => TamagotchiAction.darUnAbrazo,
      StatKind.social => TamagotchiAction.hablar,
    };
    final seb = low.who == LineSpeaker.sebastian;
    final line = switch (action) {
      TamagotchiAction.dormir => seb ? 'Estoy muerto… ¿dormimos? Da?' : 'No puedo más, necesito dormir.',
      TamagotchiAction.cenar => seb ? 'Tengo un hambre, blyat… ¿hago milanesas?' : '¿Cenamos algo? Me muero de hambre.',
      TamagotchiAction.ponerMusica => seb ? 'Qué día gris… ¿ponemos un disco?' : 'Pongamos música, porfa.',
      TamagotchiAction.darUnAbrazo => seb ? 'Vení, gatito… necesito un abrazo.' : '¿Un abracito? Solo uno.',
      _ => seb ? 'Contame algo, dale. Privet, ¿hay alguien?' : '¿Charlamos un rato?',
    };
    say(low.who, line);
    wish.value = action;
    Sfx.instance.play('wish@0.7');
    _wishAge = 0;
  }

  /// Back from the rooftop chicken hunt: the play counts, and they comment on it.
  void _backFromRoof(int? best) {
    Music.instance.fadeTo('casa');
    if (best == null) return; // left without playing
    tamagotchi.activar(TamagotchiAction.jugar);
    _stopAll();
    _bubbles.clear();
    _nextChat = _clock + 35;
    final lines = best >= 15
        ? [(_m, '¿$best gallinas? ¡Sos un tigre!', false), (_s, 'Da. Un tigre con anteojos. Spasibo.', false)]
        : best >= 6
            ? [(_m, '¿Cuántas atrapaste?', false), (_s, '$best. La dorada casi me gana, blyat.', false)]
            : [(_m, '¿Y? ¿Cuántas?', false), (_s, '$best… las gallinas de Barcelona son rapidísimas, suka.', false), (_m, 'Mañana revancha.', false)];
    _playLines(lines, after: 0.8);
  }

  /// After the night (or «Saltar»): back in the flat, rested.
  void _goodMorning() {
    _stopAll();
    _bubbles.clear();
    _nextChat = _clock + 40;
    _playLines(_morning[_rnd.nextInt(_morning.length)], after: 1.2);
  }

  /// Sebastián makes milanesas a la napolitana, then they eat them together.
  void _dinnerTime() {
    _stopAll();
    say(LineSpeaker.maxito, _pick(const ['¿Milanesas? ¡Te amo!', '¡Qué rico huele, Sebas!', 'Yo pongo la mesa.']));
    say(LineSpeaker.sebastian, _pick(const ['Receta de mi vieja, no se discute.', 'A la napolitana, como en Buenos Aires.']), delay: 3.2);
    sebastianAnim.play(_cook, onDone: () {
      duoAnim.play(_dinner, seconds: 16); // then the «full» frame once
      say(LineSpeaker.sebastian, _pick(const ['¡A comer!', 'Con limón, obvio.', 'Las mejores milanesas de Barcelona.']));
      say(LineSpeaker.maxito, _pick(const ['Mmm… casate conmigo otra vez.', 'Dame un bocado del tuyo.', 'Esto es mejor que cualquier restaurante.']), delay: 6);
      _burst(5, delay: 16.5);
    });
  }

  void _stopAll() {
    if (Sebastian.isFocused) Sebastian.exitDialogue();
    if (MaxitoController.instance.state.isCloseUp) MaxitoController.instance.rest();
    sebastianAnim.cancel();
    maxitoAnim.cancel();
    duoAnim.cancel();
    if (Music.instance.track == 'baile') Music.instance.fadeTo('casa'); // the dance was cut short
  }

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  /// A joint conversation from the events catalogue (R18), line by line.
  /// Returns how long it lasts (seconds).
  double startChat({JointDialogue? dialogue, double after = 0}) {
    final d = dialogue ?? kJointDialogues[_rnd.nextInt(kJointDialogues.length)];
    return _playLines(
      [
        for (final line in d.lines)
          if (line.speaker != LineSpeaker.ambiente)
            (line.speaker, line.speaker == LineSpeaker.sebastian ? _withRussian(line.text) : line.text, line.interruptsPrevious),
      ],
      after: after,
    );
  }

  /// Lines one after another (a cut-in starts before the previous one ends).
  /// Returns how long it lasts (seconds, counted from now).
  double _playLines(List<(LineSpeaker, String, bool)> lines, {double after = 0}) {
    final begin = _clock + 0.3 + after;
    var at = begin;
    var last = begin;
    double? prevDur;
    for (final (who, text, cutsIn) in lines) {
      final dur = _durationOf(text);
      if (prevDur != null && cutsIn) at -= prevDur * 0.4;
      _bubbles.add(_Bubble(who, text, start: at, end: at + dur));
      last = math.max(last, at + dur);
      at += dur + 0.7;
      prevDur = dur;
    }
    return last - _clock;
  }

  /// Sebastián picked up Russian from Maxito and throws it in every now and then.
  String _withRussian(String text) {
    final roll = _rnd.nextDouble();
    if (roll < 0.14) return '${_pick(const ['Da, ', 'Da, da… ', 'Blyat, ', 'Suka… ', 'Privet… '])}${_lowerFirst(text)}';
    if (roll < 0.26) return '$text ${_pick(const ['Spasibo.', 'Da.', 'Blyat.', 'Suka.'])}';
    return text;
  }

  String _lowerFirst(String s) {
    if (s.isEmpty) return s;
    final first = s[0];
    // keep «¿¡» and names as they are
    if ('¿¡'.contains(first) || s.startsWith('Maxito') || s.startsWith('Sebas')) return s;
    return first.toLowerCase() + s.substring(1);
  }

  void say(LineSpeaker who, String text, {double delay = 0}) {
    final start = _clock + delay;
    _bubbles.add(_Bubble(who, text, start: start, end: start + _durationOf(text)));
  }

  void _pair(String a, String b, {required LineSpeaker first}) {
    final second = first == LineSpeaker.sebastian ? LineSpeaker.maxito : LineSpeaker.sebastian;
    say(first, a);
    say(second, b, delay: _durationOf(a) + 0.6);
  }

  double _durationOf(String text) => (2.6 + text.length * 0.075).clamp(3.2, 8.0);

  String _pick(List<String> options) => options[_rnd.nextInt(options.length)];

  void _burst(int n, {double delay = 0}) {
    final a = _headOf(LineSpeaker.sebastian), b = _headOf(LineSpeaker.maxito);
    if (a == null || b == null) return;
    Sfx.instance.play('sparkle@0.55', delay: delay);
    final x = (a.dx + b.dx) / 2;
    final y = math.min(a.dy, b.dy) + 60;
    for (var i = 0; i < n; i++) {
      _hearts.add(_Heart(
        ui.Offset(x + (_rnd.nextDouble() - 0.5) * 90, y + _rnd.nextDouble() * 60),
        born: _clock + delay + i * 0.12,
        size: 7 + _rnd.nextDouble() * 6,
        drift: (_rnd.nextDouble() - 0.5) * 30,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // where things are on screen
  // ---------------------------------------------------------------------------

  /// The pair frame of the current duo animation: where it lands and its scale.
  ({ui.Rect dst, double k})? _duoPlacement() {
    final frame = duoAnim.frame;
    final data = duoAnim.data;
    if (frame == null || data == null) return null;
    final view = game.size;
    final room = RoomLayout(canvas: ui.Size(view.x, view.y));
    final h = (view.y * 0.52).clamp(120.0, 640.0); // same height as the idle characters
    final feet = room.floorLineY.clamp(h * 0.6, view.y - 6.0);
    var k = h / data.refHeight;
    k = math.min(k, (view.x - 12) / frame.width); // a wide sitting scene never leaves the screen
    final mid = room.toCanvas(const ui.Offset(0.5, 0)).dx.clamp(frame.width * k / 2 + 6, view.x - frame.width * k / 2 - 6);
    return (
      dst: ui.Rect.fromLTWH(mid - data.centerX * k, feet - data.feetY * k, frame.width * k, frame.height * k),
      k: k,
    );
  }

  /// Top of a character's head right now (duo frame, or the character itself).
  ui.Offset? _headOf(LineSpeaker who) {
    final duo = duoAnim.data;
    final placed = _duoPlacement();
    if (duo != null && placed != null && duo.duoHeads.isNotEmpty) {
      final heads = duo.duoHeads[duoAnim.frameIndex.clamp(0, duo.duoHeads.length - 1)];
      final h = heads[who == LineSpeaker.sebastian ? 0 : 1];
      return placed.dst.topLeft + h * placed.k;
    }
    final c = who == LineSpeaker.sebastian ? sebastian : maxito;
    if (c == null) return null;
    return ui.Offset(c.position.x, c.position.y - c.size.y * c.scale.y);
  }

  // ---------------------------------------------------------------------------
  // loop
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    // after the app was in the background the first frame brings a huge dt: lines and
    // hearts continue where they were instead of vanishing (animations clamp the same way)
    dt = dt.clamp(0.0, 0.1);
    _clock += dt;
    sebastianAnim.update(dt);
    maxitoAnim.update(dt);
    duoAnim.update(dt);
    _bubbles.removeWhere((b) => _clock > b.end);
    speaking
      ..clear()
      ..addAll(_bubbles.where((b) => _clock >= b.start).map((b) => b.speaker == LineSpeaker.sebastian ? 'sebastian' : 'maxito'));
    for (final b in _bubbles) {
      if (!b.voiced && _clock >= b.start) {
        b.voiced = true; // a few babbled syllables when a line appears
        Sfx.instance.play(b.speaker == LineSpeaker.sebastian ? 'voice_seb@0.6' : 'voice_max@0.6', variants: 2);
      }
    }
    _checkWishes(dt);
    _hearts.removeWhere((h) => _clock > h.born + 1.8);

    // they chat by themselves now and then, standing where they are, when nothing else is going on
    if (_clock > _nextChat && !_busy && !_someoneFocused && !Sleep.instance.active) {
      startChat();
      _nextChat = _clock + 45 + _rnd.nextDouble() * 30;
    }

    // Tamagotchi drift, once a second (the HUD redraws on each notify)
    _driftAcc += dt;
    if (_driftAcc >= 1) {
      tamagotchi.avanzar(Duration(milliseconds: (_driftAcc * 1000).round()));
      _driftAcc = 0;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final placed = _duoPlacement();
    final frame = duoAnim.frame;
    if (placed != null && frame != null) {
      final data = duoAnim.data!;
      paintShadow(
        canvas,
        ui.Offset(placed.dst.left + data.centerX * placed.k, placed.dst.top + data.feetY * placed.k - 3),
        placed.dst.width * 0.75,
      );
      canvas.drawImageRect(
        frame,
        ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
        placed.dst,
        _duoPaint,
      );
      for (final (who, tag) in [(LineSpeaker.sebastian, _sebTag), (LineSpeaker.maxito, _maxTag)]) {
        final head = _headOf(who);
        if (head != null) tag.paint(canvas, head - const ui.Offset(0, 4));
      }
    }
    for (final h in _hearts) {
      h.paint(canvas, _clock);
    }
    final rects = <ui.Rect>[];
    for (final b in _bubbles.where((b) => _clock >= b.start)) {
      final head = _headOf(b.speaker);
      if (head == null) continue;
      rects.add(b.paint(canvas, head, game.size.x, rects, _clock));
    }
  }

  // ---------------------------------------------------------------------------
  // what they say for each action (Sebastián: rioplatense «vos», Maxito: neutral)
  // ---------------------------------------------------------------------------


  static const _s = LineSpeaker.sebastian;
  static const _m = LineSpeaker.maxito;

  /// Wine: a whole conversation while they clink and sip.
  static const List<List<(LineSpeaker, String, bool)>> _wineChats = [
    [
      (_s, '¡Privet! ¿Abrimos el tinto?', false),
      (_m, 'Da. Pero el bueno, no el del súper.', false),
      (_s, 'Da, da… el Priorat. Spasibo por acordarte.', false),
      (_m, 'Tu ruso mejora con cada copa.', false),
      (_s, 'Blyat, se me cayó una gota en la camisa.', false),
      (_m, 'Esa camisa ya vio cosas peores.', true),
      (_s, 'Suka… tenés razón.', false),
    ],
    [
      (_m, 'Brindemos por Barcelona.', false),
      (_s, 'Y por vos. ¡Na zdorovie! ¿Así se dice?', false),
      (_m, 'Casi. Sonó como si pidieras un taxi.', false),
      (_s, 'Da. Un taxi directo a tu corazón.', false),
      (_m, 'Qué cursi sos, Sebas.', false),
      (_s, 'Spasibo. Lo aprendí de vos.', false),
    ],
    [
      (_s, 'Este vino está increíble, blyat.', false),
      (_m, '¡No digas eso con la boca llena de vino!', true),
      (_s, 'Da, da. Perdón. Spasibo por servirlo.', false),
      (_m, 'Otra copa y me recitás a Pushkin.', false),
      (_s, 'Privet, Pushkin. Listo, ya lo recité.', false),
      (_m, 'Te amo, idiota.', false),
      (_s, 'Da.', false),
    ],
    [
      (_m, '¿Te acordás de nuestra primera copa?', false),
      (_s, 'En el Born, con aquel camarero que no nos entendía.', false),
      (_m, 'Porque le pediste vino en ruso.', false),
      (_s, 'Le dije «privet» y «spasibo». Suka, era perfecto.', false),
      (_m, 'Y después le dijiste «blyat» a la cuenta.', true),
      (_s, 'Da. La cuenta se lo merecía.', false),
    ],
  ];

  /// Good morning.
  static const List<List<(LineSpeaker, String, bool)>> _morning = [
    [(_m, '¡Buen día, dormilón!', false), (_s, 'Privet… ¿ya es de día? Blyat.', false), (_m, 'Café. Ahora.', false), (_s, 'Da, da. Spasibo.', false)],
    [(_s, '¡Buen día! Dormí como un gato.', false), (_m, 'Porque sos un gato.', false), (_s, 'Da. Un gato con hambre.', false)],
    [(_m, 'Me robaste toda la manta otra vez.', false), (_s, 'Suka… no me acuerdo de nada.', false), (_m, 'Qué conveniente.', true)],
  ];

  /// When the game opens.
  static const List<List<(LineSpeaker, String, bool)>> _hello = [
    [(_s, '¡Privet, Maxito!', false), (_m, '¡Privet, Sebas! Tu acento es un desastre.', false), (_s, 'Da. Pero es mi desastre.', false)],
    [(_m, 'Llegó alguien… ¡hola!', false), (_s, '¡Privet! Pasá, que hay vino.', false)],
    [(_s, 'Da, da, ya sé: llegaste. Privet.', false), (_m, 'Qué recibimiento más cálido.', false)],
  ];
  static const _hugMax = ['Vení acá, gatito.', 'Abrazo obligatorio, ya.', 'Te extrañé todo el día.'];
  static const _hugSeb = ['Cinco minutos más así.', 'Olés a vino y a casa.', 'No me sueltes, eh.', 'Spasibo, gatito.', 'Da… así, quedate.'];
  static const _playMax = ['¡Te persigo por el pasillo!', '¡El que pierde lava los platos!', '¿Carrera hasta el balcón?'];
  static const _playSeb = ['Con estas zapatillas no me alcanzás.', 'Hacés trampa, siempre.', 'Dale, pero sin morder.', '¡Blyat, sos rapidísimo!', 'Suka… me ganaste otra vez.'];
}

class _Bubble {
  _Bubble(this.speaker, this.text, {required this.start, required this.end});

  final LineSpeaker speaker;
  final String text;
  final double start;
  final double end;
  bool voiced = false;
  TextPainter? _tp;
  bool _laidOutWithFont = false;

  static const _paper = Color(0xFFFFF6E6);
  static const _ink = Color(0xFF2B1830);

  ui.Rect paint(ui.Canvas canvas, ui.Offset head, double screenW, List<ui.Rect> placed, double clock) {
    if (!_laidOutWithFont && NameTag.fontReady) _tp = null; // the pixel font arrived: lay out again
    _laidOutWithFont = NameTag.fontReady;
    final tp = _tp ??= TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.pixelifySans(fontSize: 15, height: 1.2, color: _ink),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: 170);
    final w = tp.width + 20;
    final h = tp.height + 16;
    final cx = head.dx.clamp(w / 2 + 6, screenW - w / 2 - 6);
    final minTop = hudBottom + 6; // never under the header
    var rect = ui.Rect.fromLTWH(cx - w / 2, head.dy - 30 - h, w, h);
    if (rect.top < minTop) rect = rect.shift(ui.Offset(0, minTop - rect.top));
    // two lines at once (one cuts in): stack them — above if there is room, else below
    for (final other in placed) {
      if (!rect.overlaps(other)) continue;
      final up = rect.shift(ui.Offset(0, other.top - rect.bottom - 8));
      rect = up.top >= minTop ? up : rect.shift(ui.Offset(0, other.bottom + 8 - rect.top));
    }
    final age = clock - start;
    final alpha = (math.min(age, end - clock) / 0.18).clamp(0.0, 1.0);
    canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, alpha));
    final body = ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8));
    final tailX = head.dx.clamp(rect.left + 14, rect.right - 14);
    final tail = ui.Path()
      ..moveTo(tailX - 7, rect.bottom - 1)
      ..lineTo(tailX, rect.bottom + 9)
      ..lineTo(tailX + 7, rect.bottom - 1)
      ..close();
    canvas.drawRRect(body.shift(const ui.Offset(0, 3)), ui.Paint()..color = const ui.Color(0x55000000));
    final fill = ui.Paint()..color = _paper;
    final line = ui.Paint()
      ..color = _ink
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, line);
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, line);
    canvas.drawRect(ui.Rect.fromLTWH(tailX - 6, rect.bottom - 2.5, 12, 3), fill); // join tail and body
    tp.paint(canvas, rect.topLeft + const ui.Offset(10, 8));
    canvas.restore();
    return rect;
  }
}

class _Heart {
  _Heart(this.origin, {required this.born, required this.size, required this.drift});

  final ui.Offset origin;
  final double born;
  final double size;
  final double drift;

  void paint(ui.Canvas canvas, double clock) {
    final t = clock - born;
    if (t < 0) return;
    final k = (t / 1.8).clamp(0.0, 1.0);
    final c = origin + ui.Offset(drift * k + math.sin(t * 5) * 4, -90 * k);
    final s = size;
    // a pixel heart: two squares and a triangle
    final paint = ui.Paint()..color = ui.Color.fromRGBO(255, 92, 138, 1 - k);
    canvas.drawRect(ui.Rect.fromLTWH(c.dx - s, c.dy - s * 0.6, s, s), paint);
    canvas.drawRect(ui.Rect.fromLTWH(c.dx, c.dy - s * 0.6, s, s), paint);
    canvas.drawPath(
      ui.Path()
        ..moveTo(c.dx - s, c.dy + s * 0.2)
        ..lineTo(c.dx + s, c.dy + s * 0.2)
        ..lineTo(c.dx, c.dy + s * 1.3)
        ..close(),
      paint,
    );
  }
}
