import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_state.dart';
import '../../game.dart';
import '../anim/frame_anim.dart';
import '../audio/music.dart';
import '../characters/maxito/maxito_state.dart';
import '../characters/sebastian/sebastian_character.dart';
import '../events/dialogues.dart';
import '../events/models.dart';
import '../tamagotchi/tamagotchi.dart';

/// Who is on screen, what they play and say: runs the HUD actions (animations,
/// music, lines, hearts), lets the two chat between themselves now and then,
/// and keeps the Tamagotchi stats drifting.
class StageDirector extends Component with HasGameReference<DosGatitosGame> {
  StageDirector() : super(priority: 20); // bubbles and hearts above everyone

  /// The characters register themselves here on load.
  static PositionComponent? sebastian;
  static PositionComponent? maxito;

  /// Frame animations currently replacing the idle sprites.
  static final FramePlayer sebastianAnim = FramePlayer();
  static final FramePlayer maxitoAnim = FramePlayer();

  static StageDirector? _instance;
  static StageDirector? get instance => _instance;

  FrameAnimData? _dance;
  FrameAnimData? _record;

  final _rnd = math.Random();
  final List<_Bubble> _bubbles = [];
  final List<_Heart> _hearts = [];
  double _clock = 0;
  double _nextChat = 18;
  double _driftAcc = 0;

  @override
  Future<void> onLoad() async {
    _instance = this;
    _dance = await FrameAnimData.load('assets/characters/sebastian/anim', 'dance');
    _record = await FrameAnimData.load('assets/characters/maxito/anim', 'record');
  }

  @override
  void onRemove() {
    if (identical(_instance, this)) _instance = null;
    super.onRemove();
  }

  bool get _someoneFocused => Sebastian.isFocused || MaxitoController.instance.state.isCloseUp;
  bool get _busy => sebastianAnim.playing || maxitoAnim.playing || _bubbles.isNotEmpty;

  // ---------------------------------------------------------------------------
  // HUD actions
  // ---------------------------------------------------------------------------

  /// Runs an action: stats (Tamagotchi core) + what the player sees and hears.
  ActionResult? act(TamagotchiAction action, {String? conQuien}) {
    final result = tamagotchi.activar(action, conQuien: conQuien);
    _nextChat = _clock + 30; // an action is a conversation of its own
    switch (action) {
      case TamagotchiAction.ponerMusica:
        _musicTime();
      case TamagotchiAction.servirVino:
        _pair(_pick(_wineSeb), _pick(_wineMax), first: LineSpeaker.sebastian);
        _burst(3);
      case TamagotchiAction.hablar:
        startChat();
      case TamagotchiAction.darUnAbrazo:
        _pair(_pick(_hugMax), _pick(_hugSeb), first: LineSpeaker.maxito);
        _burst(9);
      case TamagotchiAction.jugar:
        _pair(_pick(_playMax), _pick(_playSeb), first: LineSpeaker.maxito);
      case TamagotchiAction.preguntar:
        break; // the HUD opens the question flow
    }
    return result;
  }

  /// Maxito puts a record on, the dance track starts and Sebastián dances.
  void _musicTime() {
    _release();
    Music.instance.start();
    maxitoAnim.play(_record, onDone: () {
      Music.instance.play('baile');
      say(LineSpeaker.maxito, _pick(const ['¡Temazo!', 'Esta es para vos, Sebas.', '¡A bailar!']));
      sebastianAnim.play(_dance, seconds: 34, onDone: () => Music.instance.play('casa'));
    });
  }

  void _release() {
    if (Sebastian.isFocused) Sebastian.exitDialogue();
    if (MaxitoController.instance.state.isCloseUp) MaxitoController.instance.rest();
  }

  // ---------------------------------------------------------------------------
  // Lines
  // ---------------------------------------------------------------------------

  /// A joint conversation from the events catalogue (R18), line by line.
  void startChat([JointDialogue? dialogue]) {
    final d = dialogue ?? kJointDialogues[_rnd.nextInt(kJointDialogues.length)];
    var at = _clock + 0.3;
    double? prevDur;
    for (final line in d.lines) {
      if (line.speaker == LineSpeaker.ambiente) continue;
      final dur = _durationOf(line.text);
      if (prevDur != null && line.interruptsPrevious) at -= prevDur * 0.4; // cuts in
      _bubbles.add(_Bubble(line.speaker, line.text, start: at, end: at + dur));
      at += dur + 0.35;
      prevDur = dur;
    }
  }

  void say(LineSpeaker who, String text, {double delay = 0}) {
    final start = _clock + delay;
    _bubbles.add(_Bubble(who, text, start: start, end: start + _durationOf(text)));
  }

  void _pair(String a, String b, {required LineSpeaker first}) {
    final second = first == LineSpeaker.sebastian ? LineSpeaker.maxito : LineSpeaker.sebastian;
    say(first, a);
    say(second, b, delay: _durationOf(a) + 0.3);
  }

  double _durationOf(String text) => (1.8 + text.length * 0.05).clamp(2.2, 5.5);

  String _pick(List<String> options) => options[_rnd.nextInt(options.length)];

  void _burst(int n) {
    final a = sebastian, b = maxito;
    if (a == null || b == null) return;
    final x = (a.position.x + b.position.x) / 2;
    final y = math.min(a.position.y - a.size.y, b.position.y - b.size.y) + 40;
    for (var i = 0; i < n; i++) {
      _hearts.add(_Heart(
        Offset(x + (_rnd.nextDouble() - 0.5) * 90, y + _rnd.nextDouble() * 60),
        born: _clock + i * 0.12,
        size: 7 + _rnd.nextDouble() * 6,
        drift: (_rnd.nextDouble() - 0.5) * 30,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // loop
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    _clock += dt;
    sebastianAnim.update(dt);
    maxitoAnim.update(dt);
    _bubbles.removeWhere((b) => _clock > b.end);
    _hearts.removeWhere((h) => _clock > h.born + 1.8);

    // they chat by themselves now and then, when nothing else is going on
    if (_clock > _nextChat && !_busy && !_someoneFocused) {
      startChat();
      _nextChat = _clock + 35 + _rnd.nextDouble() * 25;
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
    for (final h in _hearts) {
      h.paint(canvas, _clock);
    }
    final placed = <ui.Rect>[];
    for (final b in _bubbles.where((b) => _clock >= b.start)) {
      final who = b.speaker == LineSpeaker.sebastian ? sebastian : maxito;
      if (who == null) continue;
      final head = ui.Offset(who.position.x, who.position.y - who.size.y * who.scale.y);
      placed.add(b.paint(canvas, head, game.size.x, placed, _clock));
    }
  }

  // ---------------------------------------------------------------------------
  // what they say for each action (Sebastián: rioplatense «vos», Maxito: neutral)
  // ---------------------------------------------------------------------------

  static const _wineSeb = ['¿Una copita de garnacha?', 'Abrí el Priorat que trajimos.', '¿Vino? Dale, es viernes en algún lado.'];
  static const _wineMax = ['Siempre. Hasta arriba, porfa.', 'Solo una. Bueno, dos.', 'Brindemos por nosotros, gatito.'];
  static const _hugMax = ['Vení acá, gatito.', 'Abrazo obligatorio, ya.', 'Te extrañé todo el día.'];
  static const _hugSeb = ['Cinco minutos más así.', 'Olés a vino y a casa.', 'No me sueltes, eh.'];
  static const _playMax = ['¡Te persigo por el pasillo!', '¡El que pierde lava los platos!', '¿Carrera hasta el balcón?'];
  static const _playSeb = ['Con estas zapatillas no me alcanzás.', 'Hacés trampa, siempre.', 'Dale, pero sin morder.'];
}

class _Bubble {
  _Bubble(this.speaker, this.text, {required this.start, required this.end});

  final LineSpeaker speaker;
  final String text;
  final double start;
  final double end;
  TextPainter? _tp;

  static const _paper = Color(0xFFFFF6E6);
  static const _ink = Color(0xFF2B1830);

  ui.Rect paint(ui.Canvas canvas, ui.Offset head, double screenW, List<ui.Rect> placed, double clock) {
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
    var cx = head.dx.clamp(w / 2 + 6, screenW - w / 2 - 6);
    var rect = ui.Rect.fromLTWH(cx - w / 2, head.dy - 40 - h, w, h);
    // two lines at once (one cuts in): stack them instead of overlapping
    for (final other in placed) {
      if (rect.overlaps(other)) rect = rect.shift(ui.Offset(0, other.top - rect.bottom - 8));
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
    // a pixel heart: two squares and a diamond
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
