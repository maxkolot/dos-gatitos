import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game.dart';
import '../audio/music.dart';
import '../audio/sfx.dart';
import '../characters/name_tag.dart';
import '../room/room_layout.dart';
import '../stage/shadow.dart';

enum _Mood { wander, idle, happy, come, greet, sleep, dance }

/// Sr. Fer, the flat's pet: wanders along the back of the room, sits and blinks,
/// dozes off when nobody plays with him, hops with joy when tapped, dances when
/// the dance track plays, and runs to the front when called (the paw button).
class SrFer extends PositionComponent with HasGameReference<DosGatitosGame>, TapCallbacks {
  SrFer() : super(anchor: Anchor.bottomCenter, priority: 2);

  static SrFer? _instance;

  /// The paw button: «¡Sr. Fer, vení!».
  static void callHim() => _instance?._call();

  static const _dir = 'assets/characters/fer';
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
  double _nextBlink = 3;
  String? _say;
  double _sayFor = 0;
  int _lastFrame = -1; // sounds go with the frames (steps, rustles)
  double _nextNoise = 8; // idle: now and then he shakes his fur or chirps

  bool get _loaded => _frames.isNotEmpty;

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
    super.onRemove();
  }

  RoomLayout get _room => RoomLayout(canvas: ui.Size(game.size.x, game.size.y));

  /// Back of the room (behind the two) and the front spot when called.
  double get _backY => _room.floorLineY - game.size.y * 0.075;
  double get _frontY => math.min(_room.floorLineY + game.size.y * 0.012, game.size.y - 8);

  /// How wide his body is on screen.
  double get _scale => (game.size.x * 0.17 / _bodyWidth) * (1 + 0.35 * _front);

  void _setMood(_Mood m) {
    _mood = m;
    _t = 0;
    _lastFrame = -1;
    if (m == _Mood.greet) Sfx.instance.play('fer_chirp', variants: 3, delay: 0.2);
    if (m == _Mood.sleep) _nextNoise = 1.5;
  }

  void _call() {
    if (!_loaded) return;
    _idleFor = 0;
    _setMood(_Mood.come);
    _targetX = game.size.x * 0.5;
    priority = 8; // in front of everyone
    Sfx.instance.play('fer_call');
    Sfx.instance.play('fer_chirp', variants: 3, delay: 0.9);
    _speak(_pick(const ['¡Me-me!', '¡Ya voy!', 'Kah may-may!']));
  }

  void _speak(String text) {
    _say = text;
    _sayFor = 2.2;
  }

  String _pick(List<String> o) => o[_rnd.nextInt(o.length)];

  @override
  void onTapDown(TapDownEvent event) {
    _idleFor = 0;
    if (_mood == _Mood.sleep) {
      _speak('¿Eh…? ¡U-nye!');
      Sfx.instance.play('fer_chirp_3');
    } else {
      _speak(_pick(const ['¡Me-me!', 'Kah may-may!', '¡Jiji!', '¡U-nye!']));
      Sfx.instance.play('fer_happy');
    }
    _setMood(_Mood.happy);
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

    // dance along with Sebastián
    final dancing = Music.instance.track == 'baile';
    if (dancing && (_mood == _Mood.idle || _mood == _Mood.wander)) _setMood(_Mood.dance);
    if (!dancing && _mood == _Mood.dance) _setMood(_Mood.idle);

    switch (_mood) {
      case _Mood.wander:
        final step = game.size.x * 0.09 * dt;
        final d = _targetX - position.x;
        if (d.abs() <= step) {
          position.x = _targetX;
          _setMood(_Mood.idle);
        } else {
          position.x += step * d.sign;
          _facing = d.sign;
        }
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
        if (_t > 1.6) _setMood(_front > 0.5 ? _Mood.greet : _Mood.idle);
      case _Mood.come:
        _front = math.min(1, _front + dt * 1.2);
        final step = game.size.x * 0.28 * dt;
        final d = _targetX - position.x;
        position.x += d.abs() <= step ? d : step * d.sign;
        if (_front >= 1 && d.abs() <= step) _setMood(_Mood.greet);
      case _Mood.greet:
        if (_t > 7) {
          // back to his corner at the back of the room
          _front = 0.999;
          _setMood(_Mood.wander);
          _targetX = game.size.x * (0.15 + 0.7 * _rnd.nextDouble());
        }
      case _Mood.sleep:
      case _Mood.dance:
        break;
    }
    if (_mood == _Mood.wander && _front > 0) {
      _front = math.max(0, _front - dt * 0.8);
      if (_front == 0) priority = 2; // behind the two again
    }
    position.y = _backY + (_frontY - _backY) * _front;
    _sounds(dt);
  }

  /// Little feet, fluffy fur, snoring: what you hear of him.
  void _sounds(double dt) {
    final img = _image;
    final frame = img == null ? -1 : identityHashCode(img);
    final changed = frame != _lastFrame;
    _lastFrame = frame;
    switch (_mood) {
      case _Mood.wander:
      case _Mood.come:
        if (changed) Sfx.instance.play(_rnd.nextBool() ? 'fer_step@0.7' : 'fer_rustle@0.45');
      case _Mood.happy:
      case _Mood.dance:
        if (changed) Sfx.instance.play('fer_rustle@0.5');
      case _Mood.idle:
        _nextNoise -= dt;
        if (_nextNoise <= 0) {
          _nextNoise = 10 + _rnd.nextDouble() * 14;
          if (_rnd.nextDouble() < 0.55) {
            Sfx.instance.play('fer_shake@0.55'); // a fluffy shake-off
          } else {
            Sfx.instance.play('fer_chirp@0.4', variants: 3);
          }
        }
      case _Mood.sleep:
        _nextNoise -= dt;
        if (_nextNoise <= 0) {
          _nextNoise = 3.4;
          Sfx.instance.play('fer_snore@0.45');
        }
      case _Mood.greet:
        break;
    }
  }

  ui.Image? get _image {
    List<ui.Image>? set(String n) => _frames[n];
    int cycle(int n, double fps) => (_t * fps).floor() % n;
    switch (_mood) {
      case _Mood.wander:
        final w = set('walk')!;
        return w[cycle(w.length, 6)];
      case _Mood.idle:
        final i = set('idle')!;
        if (_nextBlink < 0) {
          if (_nextBlink < -0.16) _nextBlink = 2.5 + _rnd.nextDouble() * 3;
          return i.length > 1 ? i[1] : i[0];
        }
        return i[0];
      case _Mood.happy:
        final h = set('happy')!;
        return h[math.min((_t * 3.5).floor(), h.length - 1)];
      case _Mood.dance:
        final h = set('happy')!;
        const seq = [0, 1, 2, 1];
        return h[seq[cycle(seq.length, 3)]];
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
    // hops: the happy frames jump, the others stand
    paintShadow(canvas, ui.Offset(w / 2, h - 2), game.size.x * 0.17 * (1 + 0.35 * _front) * 0.8);
    canvas.save();
    if (_mood == _Mood.wander && _facing < 0) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1); // the walk art faces right
    }
    canvas.drawImageRect(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), ui.Rect.fromLTWH(0, 0, w, h), _paint);
    canvas.restore();
    if (_mood != _Mood.sleep) _tag.paint(canvas, ui.Offset(w / 2, h * 0.12));
    final say = _say;
    if (say != null) _bubble(canvas, say, ui.Offset(w / 2, h * 0.12 - 30));
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
