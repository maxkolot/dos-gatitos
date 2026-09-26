import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_state.dart';
import '../../game.dart';
import '../audio/sfx.dart';
import '../characters/name_tag.dart';
import '../events/models.dart';
import '../room/room_layout.dart';
import '../sleep/sleep.dart';
import '../stage/shadow.dart';
import '../stage/stage_director.dart';

enum _Mood {
  wander,
  idle,
  happy,
  come,
  greet,
  sleep,
  dance,
  toSofa,
  jumpUp,
  sofa,
  jumpDown,
  toShoulder,
  shoulder,
  fromShoulder,
}

/// Sr. Fer, the flat's pet: wanders along the back of the room, sits and blinks,
/// dozes off when nobody plays with him, hops with joy when tapped, runs to the
/// front when called (the paw button).
///
/// With the two: while they sit down for a scene (dinner, cushions, wine) he
/// bounces on the sofa, out of their way; in a hug he jumps onto one of their
/// shoulders; when Sebastián dances he dances between them. Asleep, a tap brings
/// the camera close ([petZoom]): the two step aside and only then his sleepy
/// sounds can be heard.
class SrFer extends PositionComponent with HasGameReference<DosGatitosGame>, TapCallbacks {
  SrFer() : super(anchor: Anchor.bottomCenter, priority: _floorPriority);

  static const _floorPriority = 2; // behind the two
  static const _frontPriority = 8; // in front of the two
  static const _perchPriority = 21; // above the duo scenes (drawn by the director at 20)

  static SrFer? _instance;

  /// The paw button: «¡Sr. Fer, vení!».
  static void callHim() => _instance?._call();

  static const _dir = 'assets/characters/fer';
  static const _beat = 60 / 112; // the dance track's tempo

  final Map<String, List<ui.Image>> _frames = {};
  double _bodyWidth = 380;

  final _rnd = math.Random();
  final NameTag _tag = NameTag('Sr. Fer', accent: const Color(0xFFFF9ECF));
  final ui.Paint _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  _Mood _mood = _Mood.idle;
  double _t = 0; // time in the current mood
  double _idleFor = 0; // time without anything happening (he dozes off)
  double _targetX = 0;
  double _facing = 1;
  double _front = 0; // 0 = back of the room, 1 = in front of everyone (called)
  double _seat = 0; // 0 = on the floor, 1 = up on the sofa
  double _perch = 0; // 0 = normal size, 1 = sitting on a shoulder (smaller)
  double _hop = 0; // pixels up in the air (jumps, bounces)
  double _nextBlink = 3;
  String? _say;
  double _sayFor = 0;

  // jumps between two points (onto / off a shoulder)
  ui.Offset _jumpFrom = ui.Offset.zero;
  LineSpeaker _perchOn = LineSpeaker.sebastian;

  // the close-up while he sleeps
  bool _dreaming = false;
  double _dreamT = 0;
  double _zoom = 0;
  double _nextSnore = 0;

  bool get _loaded => _frames.isNotEmpty;
  bool get _onSofaTrip => _mood == _Mood.toSofa || _mood == _Mood.jumpUp || _mood == _Mood.sofa;
  bool get _onShoulderTrip => _mood == _Mood.toShoulder || _mood == _Mood.shoulder;
  bool get _busyWithThem => _onSofaTrip || _onShoulderTrip || _mood == _Mood.jumpDown || _mood == _Mood.fromShoulder;

  @override
  Future<void> onLoad() async {
    _instance = this;
    try {
      final meta = jsonDecode(await rootBundle.loadString('$_dir/fer.json')) as Map<String, dynamic>;
      _bodyWidth = (meta['bodyWidth'] as num).toDouble();
      for (final entry in (meta['sets'] as Map<String, dynamic>).entries) {
        final list = <ui.Image>[];
        for (final f in (entry.value['frames'] as List).cast<String>()) {
          final data = await rootBundle.load('$_dir/$f');
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
          list.add((await codec.getNextFrame()).image);
        }
        _frames[entry.key] = list;
      }
    } catch (e) {
      debugPrint('Sr. Fer: $e'); // the flat simply has no pet then
    }
    position = Vector2(game.size.x * 0.5, _backY);
    _targetX = position.x;
  }

  @override
  void onRemove() {
    if (identical(_instance, this)) _instance = null;
    petZoom.value = 0;
    super.onRemove();
  }

  RoomLayout get _room => RoomLayout(canvas: ui.Size(game.size.x, game.size.y));

  /// Back of the room (behind the two) and the front spot when called.
  double get _backY => _room.floorLineY - game.size.y * 0.075;
  double get _frontY => math.min(_room.floorLineY + game.size.y * 0.012, game.size.y - 8);

  /// The middle of the sofa's seat.
  ui.Offset get _sofaSeat => _room.toCanvas(const ui.Offset(0.26, 0.5));

  /// Where he sits on [_perchOn]'s outer shoulder during the hug (screen).
  ui.Offset? get _shoulder {
    final head = StageDirector.headOf(_perchOn);
    if (head == null) return null;
    final h = StageDirector.duoFigureHeight ?? game.size.y * 0.52;
    final side = _perchOn == LineSpeaker.sebastian ? -1.0 : 1.0;
    return head + ui.Offset(side * h * 0.1, h * 0.2);
  }

  /// How wide his body is on screen.
  double get _bodyOnScreen =>
      game.size.x * 0.17 * (1 + 0.35 * _front) * (1 - 0.18 * _seat) * (1 - 0.42 * _perch) * (1 - 0.1 * stageBack);
  double get _scale => _bodyOnScreen / _bodyWidth;

  void _setMood(_Mood m) {
    _mood = m;
    _t = 0;
    if (m == _Mood.greet) Sfx.instance.play('fer_chirp@0.7', variants: 3, delay: 0.2);
  }

  void _call() {
    if (!_loaded) return;
    _idleFor = 0;
    if (_dreaming) _endDream();
    Sfx.instance.play('fer_call');
    if (_busyWithThem || _mood == _Mood.dance) {
      _speak('¡Me-me!'); // he is busy with the two: just a wave
      return;
    }
    _setMood(_Mood.come);
    _targetX = game.size.x * 0.5;
    priority = _frontPriority;
    _speak(_pick(const ['¡Me-me!', '¡Ya voy!', 'Kah may-may!']));
  }

  void _speak(String text, {double seconds = 2.2}) {
    _say = text;
    _sayFor = seconds;
  }

  String _pick(List<String> o) => o[_rnd.nextInt(o.length)];

  @override
  void onTapDown(TapDownEvent event) {
    _idleFor = 0;
    if (_mood == _Mood.sleep && !_dreaming) {
      _startDream(); // a closer look at the sleeping one
      return;
    }
    if (_dreaming) {
      _endDream();
      _speak('¿Eh…? ¡U-nye!');
      Sfx.instance.play('fer_chirp_3@0.7');
      _setMood(_Mood.happy);
      return;
    }
    _speak(_pick(const ['¡Me-me!', 'Kah may-may!', '¡Jiji!', '¡U-nye!']));
    Sfx.instance.play('fer_happy@0.7');
    if (!_busyWithThem && _mood != _Mood.dance) _setMood(_Mood.happy);
  }

  void _startDream() {
    _dreaming = true;
    _dreamT = 0;
    _nextSnore = 1.8; // the snoring comes once the camera is close
    final h = (_image?.height ?? 400) * _scale;
    petFocus = ui.Offset(position.x, position.y - h * 0.45);
  }

  void _endDream() {
    _dreaming = false;
    _say = null;
    _idleFor = 0;
  }

  void _jump(_Mood m) {
    _jumpFrom = ui.Offset(position.x, position.y);
    _setMood(m);
  }

  @override
  void update(double dt) {
    dt = math.min(dt, 0.1);
    super.update(dt);
    if (!_loaded) return;
    _t += dt;
    _sayFor -= dt;
    if (_sayFor <= 0) _say = null;
    _nextBlink -= dt;

    final scene = StageDirector.duoAnim.playing ? StageDirector.duoAnim.data?.name : null;
    final dancing = StageDirector.sebastianAnim.playing && StageDirector.sebastianAnim.data?.name == 'dance';

    // what the two are doing decides where he goes
    if (scene == 'hug' && !_busyWithThem) {
      if (_dreaming) _endDream();
      _perchOn = _rnd.nextBool() ? LineSpeaker.sebastian : LineSpeaker.maxito;
      _setMood(_Mood.toShoulder); // watches them walk up to each other, then jumps (below)
    } else if (scene != null && scene != 'hug' && !_busyWithThem) {
      if (_dreaming) _endDream();
      priority = _floorPriority;
      _targetX = _sofaSeat.dx;
      _setMood(_Mood.toSofa);
    } else if (dancing && !_busyWithThem && _mood != _Mood.dance) {
      if (_dreaming) _endDream();
      _setMood(_Mood.dance);
    }

    switch (_mood) {
      case _Mood.wander:
        _walkTo(game.size.x * 0.09, dt, then: _Mood.idle);
      case _Mood.idle:
        _idleFor += dt;
        if (_idleFor > 70) {
          _setMood(_Mood.sleep); // nobody plays with him: nap
        } else if (_t > 3 + _rnd.nextDouble() * 4 && _front == 0) {
          // a little walk along the back of the room
          _targetX = game.size.x * (0.1 + 0.8 * _rnd.nextDouble());
          _setMood(_Mood.wander);
        }
      case _Mood.happy:
        _hop = math.sin((_t / 0.5).clamp(0.0, 1.0) * math.pi) * game.size.y * 0.035;
        if (_t > 1.6) {
          _hop = 0;
          _setMood(_front > 0.5 ? _Mood.greet : _Mood.idle);
        }
      case _Mood.come:
        _front = math.min(1, _front + dt * 1.2);
        _walkTo(game.size.x * 0.28, dt);
        if (_front >= 1 && (position.x - _targetX).abs() < 1) _setMood(_Mood.greet);
      case _Mood.greet:
        if (_t > 7) _backToTheRoom();
      case _Mood.dance:
        // between the two, bouncing on the beat and turning every other beat
        final a = StageDirector.sebastian, b = StageDirector.maxito;
        if (a != null && b != null) _targetX = (a.position.x + b.position.x) / 2;
        _front = math.max(0, _front - dt * 1.5);
        _walkTo(game.size.x * 0.25, dt, face: false);
        final beat = (_t / _beat) % 1;
        _hop = math.sin(beat * math.pi) * game.size.y * 0.022;
        _facing = ((_t / _beat).floor() ~/ 2).isEven ? 1 : -1;
        if (priority != _frontPriority) priority = _frontPriority;
        if (!dancing) {
          _hop = 0;
          _backToTheRoom();
        }
      case _Mood.toSofa:
        _front = math.max(0, _front - dt * 1.5);
        _walkTo(game.size.x * 0.22, dt);
        if ((position.x - _targetX).abs() < 1 && _front == 0) _setMood(_Mood.jumpUp);
      case _Mood.jumpUp:
        final k = (_t / 0.55).clamp(0.0, 1.0);
        _seat = Curves.easeOut.transform(k);
        _hop = math.sin(k * math.pi) * game.size.y * 0.07;
        if (k >= 1) {
          _hop = 0;
          _setMood(_Mood.sofa);
        }
      case _Mood.sofa:
        // bounces on the cushions, rests, bounces again
        final phase = _t % 2.4;
        _hop = phase < 0.9 ? math.sin((phase % 0.45) / 0.45 * math.pi) * game.size.y * 0.03 : 0;
        if (scene == null) {
          _hop = 0;
          _setMood(_Mood.jumpDown);
        }
      case _Mood.jumpDown:
        final k = (_t / 0.5).clamp(0.0, 1.0);
        _seat = 1 - Curves.easeIn.transform(k);
        _hop = math.sin(k * math.pi) * game.size.y * 0.05;
        if (k >= 1) {
          _seat = 0;
          _hop = 0;
          _idleFor = 0;
          _setMood(_Mood.idle);
        }
      case _Mood.toShoulder:
        final target = _shoulder;
        if (scene != 'hug' || target == null) {
          _perch = 0;
          _setMood(_Mood.idle);
          break;
        }
        if (priority != _perchPriority && StageDirector.duoAnim.frameIndex < 2) {
          _t = 0; // they are still walking up to each other
          break;
        }
        if (priority != _perchPriority) {
          priority = _perchPriority;
          _jumpFrom = ui.Offset(position.x, position.y);
          Sfx.instance.play('fer_happy@0.5');
        }
        final k = (_t / 0.7).clamp(0.0, 1.0);
        final e = Curves.easeInOut.transform(k);
        _perch = e;
        final p = ui.Offset.lerp(_jumpFrom, target, e)!;
        _facing = target.dx < _jumpFrom.dx ? -1 : 1;
        position.setValues(p.dx, p.dy - math.sin(k * math.pi) * game.size.y * 0.1);
        if (k >= 1) _setMood(_Mood.shoulder);
      case _Mood.shoulder:
        final target = _shoulder;
        if (scene != 'hug' || target == null) {
          _jump(_Mood.fromShoulder);
          break;
        }
        // rides along as they sway
        final f = (dt * 6).clamp(0.0, 1.0);
        position.setValues(position.x + (target.dx - position.x) * f, position.y + (target.dy - position.y) * f);
      case _Mood.fromShoulder:
        final k = (_t / 0.6).clamp(0.0, 1.0);
        final e = Curves.easeIn.transform(k);
        _perch = 1 - e;
        final land = ui.Offset(_jumpFrom.dx + (_jumpFrom.dx < game.size.x / 2 ? -1 : 1) * game.size.x * 0.12, _backY);
        final p = ui.Offset.lerp(_jumpFrom, land, e)!;
        position.setValues(p.dx, p.dy - math.sin(k * math.pi) * game.size.y * 0.06);
        if (k >= 1) {
          _perch = 0;
          priority = _floorPriority;
          _idleFor = 0;
          _setMood(_Mood.idle);
        }
      case _Mood.sleep:
        break;
    }
    if (_mood == _Mood.wander && _front > 0) {
      _front = math.max(0, _front - dt * 0.8);
      if (_front == 0) priority = _floorPriority;
    }
    if (!_onShoulderTrip && _mood != _Mood.fromShoulder) {
      final floorY = _backY + (_frontY - _backY) * _front;
      position.y = floorY + (_sofaSeat.dy - floorY) * _seat - _hop;
    }

    _updateDream(dt);
  }

  void _walkTo(double speed, double dt, {_Mood? then, bool face = true}) {
    final step = speed * dt;
    final d = _targetX - position.x;
    if (d.abs() <= step) {
      position.x = _targetX;
      if (then != null) _setMood(then);
    } else {
      position.x += step * d.sign;
      if (face) _facing = d.sign;
    }
  }

  void _backToTheRoom() {
    _front = math.max(_front, 0.001);
    _targetX = game.size.x * (0.15 + 0.7 * _rnd.nextDouble());
    _setMood(_Mood.wander);
  }

  /// The close-up of the sleeping one: camera in, the two step aside, snoring.
  void _updateDream(double dt) {
    if (_dreaming) {
      _dreamT += dt;
      final interrupted = _mood != _Mood.sleep || StageDirector.sebastianAnim.playing || StageDirector.maxitoAnim.playing || Sleep.instance.active;
      if (interrupted || _dreamT > 18) _endDream();
    }
    final target = _dreaming ? 1.0 : 0.0;
    _zoom = target > _zoom ? math.min(1, _zoom + dt / 1.8) : math.max(0, _zoom - dt / 1.2);
    final eased = Curves.easeInOutCubic.transform(_zoom);
    if (petZoom.value != eased) petZoom.value = eased;

    // his sleepy sounds, only up close
    if (_dreaming && _zoom > 0.85) {
      _nextSnore -= dt;
      if (_nextSnore <= 0) {
        _nextSnore = 3.6;
        Sfx.instance.play('fer_snore@0.9');
        _speak('Zzz…', seconds: 2.4);
      }
    }
  }

  ui.Image? get _image {
    List<ui.Image>? set(String n) => _frames[n];
    int cycle(int n, double fps) => (_t * fps).floor() % n;
    ui.Image idle() {
      final i = set('idle')!;
      if (_nextBlink < 0) {
        if (_nextBlink < -0.16) _nextBlink = 2.5 + _rnd.nextDouble() * 3;
        return i.length > 1 ? i[1] : i[0];
      }
      return i[0];
    }

    switch (_mood) {
      case _Mood.wander:
      case _Mood.toSofa:
        final w = set('walk')!;
        return w[cycle(w.length, _mood == _Mood.toSofa ? 9 : 6)];
      case _Mood.idle:
      case _Mood.shoulder:
        return idle();
      case _Mood.happy:
        final h = set('happy')!;
        return h[math.min((_t * 3.5).floor(), h.length - 1)];
      case _Mood.dance:
        final h = set('happy')!;
        const seq = [0, 1, 2, 1];
        return h[seq[((_t / _beat).floor()) % seq.length]];
      case _Mood.jumpUp:
      case _Mood.jumpDown:
      case _Mood.fromShoulder:
        final h = set('happy')!;
        return h[math.min(1, h.length - 1)];
      case _Mood.toShoulder:
        if (priority != _perchPriority) return idle(); // waiting for the embrace
        final h = set('happy')!;
        return h[math.min(1, h.length - 1)];
      case _Mood.sofa:
        final h = set('happy')!;
        if (_hop > 0) return h[cycle(h.length, 5)];
        return idle();
      case _Mood.come:
        final c = set('come')!;
        return c[cycle(2, 6)];
      case _Mood.greet:
        final c = set('come')!;
        return c[_t < 1.4 ? 2 : 3];
      case _Mood.sleep:
        final s = set('sleep')!;
        if (_t < 1.4) return s[0];
        return s[1 + cycle(2, 0.8)];
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final img = _image;
    if (img == null) return;
    final s = _scale;
    final w = img.width * s;
    final h = img.height * s;
    size = Vector2(w, h);
    // the shadow stays on the floor (or the seat) while he is in the air; none on a shoulder
    if (_perch < 0.5) {
      final lift = (_hop / (h * 0.6)).clamp(0.0, 1.0);
      paintShadow(canvas, ui.Offset(w / 2, h - 2 + _hop), _bodyOnScreen * 0.8, lift: lift);
    }
    canvas.save();
    final flip = _facing < 0 && (_mood == _Mood.wander || _mood == _Mood.toSofa || _mood == _Mood.dance || _mood == _Mood.toShoulder);
    if (flip) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1); // the walk art faces right
    }
    canvas.drawImageRect(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), ui.Rect.fromLTWH(0, 0, w, h), _paint);
    canvas.restore();
    if (_mood != _Mood.sleep && _perch < 0.3) _tag.paint(canvas, ui.Offset(w / 2, h * 0.12));
    final say = _say;
    if (say != null) _bubble(canvas, say, ui.Offset(w / 2, h * 0.12 - (_mood == _Mood.sleep ? 0 : 30)));
  }

  TextPainter? _sayTp;
  String? _sayText;

  void _bubble(ui.Canvas canvas, String text, ui.Offset bottom) {
    if (_sayText != text || _sayTp == null) {
      _sayText = text;
      _sayTp = TextPainter(
        text: TextSpan(text: text, style: GoogleFonts.pixelifySans(fontSize: 14, color: const Color(0xFF2B1830))),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final tp = _sayTp!;
    final r = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(center: bottom - ui.Offset(0, tp.height / 2 + 6), width: tp.width + 16, height: tp.height + 10),
      const ui.Radius.circular(7),
    );
    canvas.drawRRect(r, ui.Paint()..color = const Color(0xFFFFF6E6));
    canvas.drawRRect(
      r,
      ui.Paint()
        ..color = const Color(0xFF2B1830)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    tp.paint(canvas, r.outerRect.topLeft + const ui.Offset(8, 5));
  }
}
