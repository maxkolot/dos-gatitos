import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/services.dart' show rootBundle;

import '../../../game.dart';
import '../../room/room_layout.dart';
import '../name_tag.dart';
import '../../anim/frame_anim.dart';
import '../../stage/stage_director.dart';
import '../sebastian/sebastian_character.dart';
import 'maxito_blink.dart';
import 'maxito_state.dart';

/// Максито — animate rig.
///
/// He lives in his corner of the flat: breathing (chest scale + tiny bob),
/// blinking, head sway and, when the player taps him, a smooth zoom-in
/// (400 ms) to the camera where he looks straight at the player, keeps
/// blinking/swaying, then returns (550 ms) to his spot.
///
/// The sprite is cut in two slices at [neckLine]: the head slice sways/rotates
/// on the neck while the body slice below keeps breathing, so the movement
/// reads as a head sway instead of the whole picture wobbling.
///
/// A sprite-based blink: the eyelid is the skin band right above the eye,
/// squashed down over the eye (that is why the eye geometry below is measured
/// from the asset with `tool/maxito_eyes.py`).
class MaxitoCharacter extends PositionComponent
    with HasGameReference<DosGatitosGame>, TapCallbacks {
  MaxitoCharacter({
    MaxitoController? controller,
    MaxitoBlink? blink,
    this.debugStateFromUrl = true,
  })  : controller = controller ?? MaxitoController.instance,
        _blink = blink ?? MaxitoBlink();

  /// Where the art lives. Loaded through [rootBundle] (+ decode) instead of
  /// `game.images`, because Flame's Images cache is hard-wired to
  /// `assets/images/` and other features rely on that prefix.
  static const String assetPath = 'assets/characters/maxito/maxito_idle.png';

  /// Split point of head / body slices, as a fraction of the sprite height.
  static const double neckLine = 0.20; // full-body art: head + neck = top fifth

  /// Slices overlap a bit so the neck seam stays invisible while the head sway.
  static const double sliceOverlap = 0.025;

  /// Eye geometry, normalized to the sprite box (measured from the asset).
  static const double eyeY = 0.143;
  static const double eyeLeftX = 0.391;
  static const double eyeRightX = 0.586;
  static const double eyeWidth = 0.048;
  static const double eyeHeight = 0.010;

  /// Zoom-in / return timing (task: 300–500 ms in, smooth return).
  static const double zoomInSeconds = 0.40;
  static const double zoomOutSeconds = 0.55;

  /// How much bigger he is when he is right in front of the camera.
  static const double closeUpScale = 2.0;

  final MaxitoController controller;
  final MaxitoBlink _blink;

  /// Lets `?maxito=talking&maxitoTalk=...` force a state for QA screenshots.
  final bool debugStateFromUrl;

  ui.Image? _image;
  double _time = 0;
  double _zoom = 0;
  double _sway = 0;
  double _bob = 0;
  double _bodyScaleY = 1;
  double _bodyScaleX = 1;
  double _lid = 0;

  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

  /// 0 = at his spot, 1 = stepped aside to the right edge while Sebastián talks.
  double _aside = 0;

  /// Sideways shift while an action animation carries props (the record cabinet) past the screen edge.
  double _animShift = 0;

  final NameTag _tag = NameTag('Maxito', accent: const ui.Color(0xFFFF9A4D));
  final _lashPaint = ui.Paint()..color = const ui.Color(0x88241416);
  final _sparkPaint = ui.Paint()..color = const ui.Color(0xFFFFD76B);

  @override
  bool get isLoaded => _image != null;

  /// Head position in screen coordinates (the bubble hangs from there).
  ui.Offset get headScreenOffset => ui.Offset(
        position.x,
        position.y - size.y + size.y * neckLine * scale.y * 0.72,
      );

  @override
  Future<void> onLoad() async {
    anchor = Anchor.bottomCenter;
    priority = 5; // over the room, under the HUD
    size = Vector2.all(200);
    _image = await _decode(assetPath);
    StageDirector.maxito = this;
    if (debugStateFromUrl) _applyDebugState();
  }

  @override
  void onRemove() {
    if (identical(StageDirector.maxito, this)) StageDirector.maxito = null;
    super.onRemove();
  }

  static Future<ui.Image> _decode(String path) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// QA hook: `?maxito=sleepy` (idle|listening|talking|playful|sleepy) plus
  /// `?maxitoTalk=Hola` to open the bubble — handy for screenshots on web.
  void _applyDebugState() {
    final params = Uri.base.queryParameters;
    final raw = params['maxito'];
    if (raw == null) return;
    final state = MaxitoState.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => MaxitoState.idle,
    );
    final line = params['maxitoTalk'] ?? '';
    switch (state) {
      case MaxitoState.talking:
        controller.say(line.isEmpty ? '¡Hola! ¿Qué tal?' : line, hold: 3600);
      case MaxitoState.sleepy:
        controller.sleep();
      case MaxitoState.playful:
        controller.play();
      case MaxitoState.listening:
        controller.focus(hold: 3600);
      case MaxitoState.idle:
        controller.rest();
    }
  }

  @override
  void update(double dt) {
    _time += dt;
    controller.tick(dt);
    _blink.update(dt);

    // --- layout: right of the pair, feet on the room's floor line ------------
    final view = game.size;
    final height = (view.y * 0.52).clamp(120.0, 640.0);
    final img = _image;
    final aspect = img == null || img.height == 0 ? 0.34 : img.width / img.height;
    size = Vector2(height * aspect, height);

    final room = RoomLayout(canvas: ui.Size(view.x, view.y));
    final feet = room.floorLineY.clamp(height, view.y - 6.0);
    final asideTarget = Sebastian.isFocused && !controller.state.isCloseUp ? 1.0 : 0.0;
    _aside += (asideTarget - _aside) * (dt * 7).clamp(0.0, 1.0);
    final spot = room.toCanvas(const ui.Offset(0.65, 0)).dx;
    // while Sebastián is in front of the camera he waits at the right edge, still tappable
    final home = Vector2(spot + (view.x * 0.88 - spot) * _aside, feet);
    // close-up: scaled around the feet, a bit right of centre so Sebastián stays tappable at the left
    final close = Vector2(view.x * 0.58, view.y + height * 0.40);
    final target = controller.state.isCloseUp ? 1.0 : 0.0;
    final step = dt * (target > _zoom ? 1 / zoomInSeconds : 1 / zoomOutSeconds);
    _zoom = target > _zoom ? min(target, _zoom + step) : max(target, _zoom - step);
    controller.zoom = _zoom;

    final eased = Curves.easeInOutCubic.transform(_zoom.clamp(0.0, 1.0));
    position = home + (close - home) * eased;
    scale = Vector2.all(1 + (closeUpScale - 1) * eased);

    // --- motion per mood -----------------------------------------------------
    final m = _motion;
    final breath = sin(_time * 2 * pi / m.breathPeriod);
    _bodyScaleY = 1 + m.breathAmp * breath;
    _bodyScaleX = 1 - m.breathAmp * 0.45 * breath;
    _bob = -m.bobAmp * (0.5 - 0.5 * cos(_time * 2 * pi / m.breathPeriod));
    _sway = m.swayAmp * sin(_time * 2 * pi / m.swayPeriod) + m.tilt;

    if (controller.state == MaxitoState.sleepy) {
      _lid = max(_blink.closedAmount, MaxitoState.sleepy.restingLid);
    } else {
      _lid = max(_blink.closedAmount, controller.state.restingLid);
    }

    // keep a whole action frame on screen: slide left while its props would stick out on the right
    var shiftTarget = 0.0;
    final anim = StageDirector.maxitoAnim;
    final data = anim.data;
    if (anim.playing && data != null && data.frames.isNotEmpty) {
      final k = size.y / data.refHeight;
      final right = position.x + (data.frames.first.width - data.centerX) * k;
      // at most 50 px: Sebastián makes room on the left, the last sleeves may stay cut
      if (right > view.x - 4) shiftTarget = max(view.x - 4 - right, -50.0);
    }
    _animShift += (shiftTarget - _animShift) * (dt * 6).clamp(0.0, 1.0);

    controller.headX = position.x;
    controller.headY = position.y - size.y * (1 - neckLine) * scale.y;
    controller.headSize = size.y * neckLine * scale.y;
  }

  _Motion get _motion => switch (controller.state) {
        MaxitoState.idle =>
          const _Motion(swayAmp: 0.022, swayPeriod: 5.4, bobAmp: 1.6, breathPeriod: 3.4),
        MaxitoState.listening =>
          const _Motion(swayAmp: 0.012, swayPeriod: 4.0, bobAmp: 0.9, breathPeriod: 3.0, tilt: 0.02),
        MaxitoState.talking =>
          const _Motion(swayAmp: 0.050, swayPeriod: 2.0, bobAmp: 2.2, breathPeriod: 2.6, tilt: -0.015),
        MaxitoState.playful =>
          const _Motion(swayAmp: 0.070, swayPeriod: 1.5, bobAmp: 5.0, breathPeriod: 1.8),
        MaxitoState.sleepy =>
          const _Motion(swayAmp: 0.030, swayPeriod: 7.5, bobAmp: 2.6, breathPeriod: 5.2, breathAmp: 0.030),
      };

  @override
  bool containsLocalPoint(Vector2 point) {
    // A tighter hitbox than the (mostly transparent) sprite box.
    final w = size.x;
    final h = size.y;
    return point.x >= w * 0.12 &&
        point.x <= w * 0.88 &&
        point.y >= h * 0.06 &&
        point.y <= h;
  }

  @override
  void onTapUp(TapUpEvent event) {
    // one talks at a time: Sebastián steps back when Maxito is chosen
    if (Sebastian.isFocused) Sebastian.exitDialogue();
    if (StageDirector.maxitoAnim.playing) StageDirector.maxitoAnim.stop();
    if (controller.state == MaxitoState.sleepy) controller.wake();
    controller.focus();
    _blink.blinkNow();
  }

  @override
  void render(ui.Canvas canvas) {
    final img = _image;
    if (img == null) return;
    final w = size.x;
    final h = size.y;
    // an action animation (the record player…) replaces the idle sprite while it plays
    final anim = StageDirector.maxitoAnim;
    final frame = anim.frame;
    if (frame != null && !controller.state.isCloseUp) {
      canvas.save();
      canvas.translate(_animShift, 0);
      paintAnimFrame(canvas, frame, anim.data!, w, h, _paint);
      _tag.paint(canvas, ui.Offset(w / 2, -4));
      canvas.restore();
      return;
    }
    final sx = img.width / w;
    final sy = img.height / h;

    // One piece (the full-body art has no clean seam to split head from body):
    // breathing scales him from the feet, the mood sway leans the whole figure a
    // little around the feet, the bob lifts him; the eyelids ride along.
    canvas.save();
    canvas.translate(w / 2, h);
    canvas.rotate(_sway * 0.25);
    canvas.scale(_bodyScaleX, _bodyScaleY);
    canvas.translate(-w / 2, -h + _bob);
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w, h),
      _paint,
    );
    _drawLids(canvas, img, w, h, sx, sy);
    canvas.restore();

    if (controller.state == MaxitoState.playful) {
      _drawSparkles(canvas, w, h);
    }
    // his name, hidden while he is in the close-up
    _tag.paint(canvas, ui.Offset(w / 2, -4), opacity: (1 - _zoom * 4).clamp(0.0, 1.0));
  }

  /// Closes the eyes with the skin band right above each eye, squashed over it.
  void _drawLids(ui.Canvas canvas, ui.Image img, double w, double h, double sx, double sy) {
    final lid = _lid.clamp(0.0, 1.0);
    if (lid <= 0.02) return;
    final eyeW = w * eyeWidth;
    final eyeH = h * eyeHeight;
    final srcBand = eyeH * 0.7;
    for (final cx in <double>[eyeLeftX, eyeRightX]) {
      final left = cx * w - eyeW / 2;
      final top = (eyeY - eyeHeight / 2) * h;
      final srcTop =
          ((top - srcBand) * sy).clamp(0.0, (img.height - srcBand * sy).toDouble());
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(left * sx, srcTop, eyeW * sx, srcBand * sy),
        ui.Rect.fromLTWH(left, top, eyeW, eyeH * lid),
        _paint,
      );
      if (lid > 0.45) {
        // lash line at the bottom edge of the closed eyelid
        final alpha = ((lid - 0.45) / 0.55).clamp(0.0, 1.0);
        _lashPaint.color = ui.Color.fromRGBO(36, 20, 22, 0.55 * alpha);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(left, top + eyeH * lid - 1.4, eyeW, 1.8),
            const ui.Radius.circular(0.9),
          ),
          _lashPaint,
        );
      }
    }
  }

  /// Small warm sparkles around Maxito in the playful mood.
  void _drawSparkles(ui.Canvas canvas, double w, double h) {
    for (var i = 0; i < 4; i++) {
      final phase = _time * 1.6 + i * 1.7;
      final pulse = 0.5 + 0.5 * sin(phase);
      final x = w * (i.isEven ? 0.10 : 0.90) + 8 * sin(phase * 0.8);
      final y = h * (0.18 + 0.16 * i) + 6 * cos(phase);
      final r = (2.2 + 2.0 * pulse);
      _sparkPaint.color = ui.Color.fromRGBO(255, 215, 107, 0.25 + 0.45 * pulse);
      canvas.drawPath(_starPath(ui.Offset(x, y), r), _sparkPaint);
    }
  }

  ui.Path _starPath(ui.Offset c, double r) => ui.Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + r * 0.22, c.dy - r * 0.22, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + r * 0.22, c.dy + r * 0.22, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - r * 0.22, c.dy + r * 0.22, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - r * 0.22, c.dy - r * 0.22, c.dx, c.dy - r)
    ..close();
}

/// Per-mood animation numbers.
class _Motion {
  const _Motion({
    required this.swayAmp,
    required this.swayPeriod,
    required this.bobAmp,
    required this.breathPeriod,
    this.breathAmp = 0.018,
    this.tilt = 0,
  });

  /// Head sway amplitude (radians) and period (seconds).
  final double swayAmp;
  final double swayPeriod;

  /// Vertical bob amplitude in pixels.
  final double bobAmp;

  /// Breathing period (seconds) and chest scale amplitude.
  final double breathPeriod;
  final double breathAmp;

  /// Constant head tilt (radians) — a mood detail.
  final double tilt;
}
