import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../../../game.dart';
import 'sebastian_animation.dart';

export 'sebastian_animation.dart';

/// Sebastián on stage: draws the sprite and drives his [SebastianAnimator]
/// from the Flame game loop (no animation package, one draw call per frame).
///
/// * idle breathing + micro movement + head sway + random blinks
/// * tap (or [enterDialogue]) → smooth 300–500 ms approach, face to player,
///   blinking and head sway while talking, then a smooth step back
///
/// Other features (dialogue, AI answers) should not talk to this component
/// directly — they use the [Sebastian] helpers at the bottom of this file.
class SebastianCharacter extends PositionComponent
    with HasGameReference<DosGatitosGame>, TapCallbacks {
  SebastianCharacter({
    this.characterHeight = 132,
    Vector2? position,
    this.autoExitAfter,
  }) : _fixedPosition = position;

  /// Rendered sprite height in logical pixels (width follows the aspect ratio).
  final double characterHeight;

  /// Optional fixed position (bottom-centre anchor). Default: bottom-left of
  /// the flat, so he never hides the cats.
  final Vector2? _fixedPosition;

  /// When set, he steps back by himself after this long without interaction.
  final Duration? autoExitAfter;

  /// Called with `true` on approach, `false` after he stepped back.
  void Function(bool inCloseUp)? onCloseUpChanged;

  final SebastianAnimator animator = SebastianAnimator();

  final Images _images = Images(prefix: 'assets/characters/sebastian/');
  Sprite? _sprite;
  Sprite? _blinkSprite;

  double _focusTime = 0;
  bool _wasCloseUp = false;

  /// Assets used by the close-up. Missing files never crash the game.
  bool get hasSprite => _sprite != null;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.bottomCenter;
    priority = 3; // above the cats, below modal UI
    size = Vector2(characterHeight * 0.85, characterHeight);

    try {
      final image = await _images.load('sebastian_idle.png');
      _sprite = Sprite(image);
      final src = _sprite!.srcSize;
      if (src.y > 0) size = Vector2(characterHeight * (src.x / src.y), characterHeight);
    } catch (_) {
      _sprite = null;
    }
    try {
      final image = await _images.load('sebastian_blink.png');
      _blinkSprite = Sprite(image);
    } catch (_) {
      // No closed-eyes frame: blinks are simply skipped.
      _blinkSprite = null;
    }

    position = _basePosition;
    Sebastian.attach(animator);
  }

  @override
  void onRemove() {
    Sebastian.detach(animator);
    super.onRemove();
  }

  Vector2 get _basePosition =>
      _fixedPosition?.clone() ??
      Vector2(game.size.x * 0.22, game.size.y - 14);

  /// Where he stands while talking to the player: centred and low, so the
  /// close-up puts his face right in front of the camera.
  Vector2 get _closeUpPosition =>
      Vector2(game.size.x / 2, game.size.y * 0.74);

  @override
  void update(double dt) {
    animator.update(dt);
    final pose = animator.pose;

    final base = _basePosition;
    final close = _closeUpPosition;
    final t = pose.zoomProgress;
    position.setValues(
      base.x + (close.x - base.x) * t,
      base.y + (close.y - base.y) * t,
    );

    if (animator.isFocused) {
      _focusTime += dt;
      final limit = autoExitAfter;
      if (limit != null && _focusTime > limit.inSeconds) exitDialogue();
    } else {
      _focusTime = 0;
    }
    if (pose.isCloseUp != _wasCloseUp) {
      _wasCloseUp = pose.isCloseUp;
      onCloseUpChanged?.call(_wasCloseUp);
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _sprite;
    if (sprite == null) return;
    final pose = animator.pose;

    // Scale around the eye line: he grows towards the camera the way a face
    // does, instead of inflating from the floor.
    final eye = Offset(size.x / 2, size.y * 0.30);

    canvas.save();
    canvas.translate(0, pose.offsetY);
    canvas.rotate(pose.rotation);
    canvas.translate(eye.dx, eye.dy);
    canvas.scale(pose.zoom, pose.zoom * pose.stretch);
    canvas.translate(-eye.dx, -eye.dy);

    _paint(canvas, sprite, 1);
    final blink = _blinkSprite;
    if (blink != null && pose.eyeOpen < 0.999) {
      _paint(canvas, blink, 1 - pose.eyeOpen);
    }
    canvas.restore();
  }

  void _paint(Canvas canvas, Sprite sprite, double opacity) {
    if (opacity >= 0.999) {
      sprite.render(canvas, size: size);
      return;
    }
    final dst = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.saveLayer(dst, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    sprite.render(canvas, size: size);
    canvas.restore();
  }

  // --- interaction ---------------------------------------------------------

  @override
  void onTapDown(TapDownEvent event) {
    if (animator.isFocused) {
      animator.poke();
    } else {
      enterDialogue();
    }
  }

  /// Smooth approach + direct gaze; also switches to [state].
  void enterDialogue([
    SebastianAnimationState state = SebastianAnimationState.listening,
  ]) {
    animator.enterDialogue(state);
    _focusTime = 0;
    if (animator.pose.isCloseUp != _wasCloseUp) {
      _wasCloseUp = animator.pose.isCloseUp;
      onCloseUpChanged?.call(_wasCloseUp);
    }
  }

  /// Smooth step back to his place.
  void exitDialogue() {
    animator.exitDialogue();
    _focusTime = 0;
  }

  /// Taps must follow the sprite, which is scaled while he is close to the
  /// camera.
  @override
  bool containsLocalPoint(Vector2 point) {
    final pose = animator.pose;
    final eye = Vector2(size.x / 2, size.y * 0.30);
    final zoom = pose.zoom == 0 ? 1.0 : pose.zoom;
    final stretch = pose.stretch == 0 ? 1.0 : pose.stretch;
    final lx = eye.x + (point.x - eye.x) / zoom;
    final ly = eye.y + (point.y - pose.offsetY - eye.y) / (zoom * stretch);
    const pad = 4;
    return lx >= -pad && lx <= size.x + pad && ly >= -pad && ly <= size.y + pad;
  }
}

/// Global handle so dialogue / AI / events can drive Sebastián without
/// knowing the widget or component tree:
///
/// ```dart
/// Sebastian.listen();                       // he turns to the player
/// Sebastian.talk();                         // he answers (head nods)
/// Sebastian.affectionate();                 // cozy mood
/// Sebastian.sleepy();                       // late evening
/// Sebastian.idle();                         // back to normal
/// Sebastian.exitDialogue();                 // smooth step back
/// ```
class Sebastian {
  Sebastian._();

  static SebastianAnimator? _active;

  /// Animator of the Sebastián currently on screen (a fresh one if none yet,
  /// so calls never throw while the game is loading).
  static SebastianAnimator get animator => _active ??= SebastianAnimator();

  static bool get isOnStage => _active != null;

  /// Called by [SebastianCharacter] when it enters/leaves the scene.
  static void attach(SebastianAnimator a) => _active = a;

  static void detach(SebastianAnimator a) {
    if (identical(_active, a)) _active = null;
  }

  static SebastianAnimationState get state => animator.state;
  static bool get isFocused => animator.isFocused;
  static double get zoom => animator.pose.zoom;

  /// Idle with breathing, sway and blinks.
  static void idle() => animator.setState(SebastianAnimationState.idle);

  /// Turns to the player and starts the close-up.
  static void listen() =>
      animator.enterDialogue(SebastianAnimationState.listening);

  /// He is answering.
  static void talk() => animator.setState(SebastianAnimationState.talking);

  /// Cozy, head tilted, half closed eyes.
  static void affectionate() =>
      animator.setState(SebastianAnimationState.affectionate);

  /// Late evening mood.
  static void sleepy() => animator.setState(SebastianAnimationState.sleepy);

  static void setState(SebastianAnimationState state) =>
      animator.setState(state);

  static void exitDialogue() => animator.exitDialogue();

  static void poke() => animator.poke();
}
