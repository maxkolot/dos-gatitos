import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../../app_state.dart';
import '../../../game.dart';
import '../../room/room_layout.dart';
import '../maxito/maxito_state.dart';
import '../name_tag.dart';
import '../../anim/frame_anim.dart';
import '../../stage/stage_director.dart';
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
    this.heightFraction = 0.52,
    Vector2? position,
    this.autoExitAfter,
  }) : _fixedPosition = position;

  /// Rendered height as a share of the screen height (width follows the art).
  final double heightFraction;

  /// Eye line of the full-body art, as a fraction of the sprite height: the
  /// close-up scales around it, so the face grows towards the camera.
  static const double eyeLine = 0.11;

  double _aspect = 0.33;

  /// 0 = at his spot, 1 = stepped aside to the left edge while Maxito talks.
  double _aside = 0;

  final NameTag _tag = NameTag('Sebastián', accent: const Color(0xFF8EC5FF));

  bool get _maxitoFocused => MaxitoController.instance.state.isCloseUp;

  final Paint _animPaint = Paint()..filterQuality = FilterQuality.medium;

  double get characterHeight => (game.size.y * heightFraction).clamp(120.0, 640.0);

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
    priority = 3; // above the room, below modal UI
    size = Vector2(characterHeight * _aspect, characterHeight);

    try {
      final image = await _images.load('sebastian_idle.png');
      _sprite = Sprite(image);
      final src = _sprite!.srcSize;
      if (src.y > 0) _aspect = src.x / src.y;
      size = Vector2(characterHeight * _aspect, characterHeight);
    } catch (_) {
      _sprite = null;
    }
    try {
      // optional frame: only ask for it when it is part of the build (a missing
      // asset is reported as an error even when caught)
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (manifest.listAssets().contains('assets/characters/sebastian/sebastian_blink.png')) {
        _blinkSprite = Sprite(await _images.load('sebastian_blink.png'));
      }
    } catch (_) {
      // No closed-eyes frame: blinks are simply skipped.
      _blinkSprite = null;
    }

    position = _basePosition;
    Sebastian.attach(animator);
    StageDirector.sebastian = this;
  }

  @override
  void onRemove() {
    Sebastian.detach(animator);
    if (identical(StageDirector.sebastian, this)) StageDirector.sebastian = null;
    super.onRemove();
  }

  /// Left of the pair, feet on the room's floor line.
  Vector2 get _basePosition {
    final fixed = _fixedPosition;
    if (fixed != null) return fixed.clone();
    final canvas = Size(game.size.x, game.size.y);
    final room = RoomLayout(canvas: canvas);
    final feet = room.floorLineY.clamp(characterHeight, game.size.y - 6.0);
    final spot = room.toCanvas(const Offset(0.35, 0)).dx;
    // while Maxito is in front of the camera he waits at the left edge, still tappable
    final aside = game.size.x * 0.12;
    return Vector2(spot + (aside - spot) * _aside, feet);
  }

  /// Where he stands while talking to the player: centred and low, so the
  /// close-up puts his face right in front of the camera.
  /// A bit left of centre, so Maxito, stepped aside to the right, stays tappable.
  Vector2 get _closeUpPosition {
    // feet placed so the top of his head (zoomed around the eye line) sits right under the header
    final header = hudBottom > 0 ? hudBottom : game.size.y * 0.23;
    final h = characterHeight;
    final feet = header + 12 + h * ((1 - eyeLine) + eyeLine * SebastianAnimator.focusZoom);
    return Vector2(game.size.x * 0.42, feet);
  }

  @override
  void update(double dt) {
    size.setValues(characterHeight * _aspect, characterHeight); // follows rotation / resize
    // Maxito in the close-up: step aside; Maxito busy at the record player: make room halfway
    final asideTarget = _maxitoFocused && !animator.isFocused
        ? 1.0
        : StageDirector.maxitoAnim.playing
            ? 0.5
            : 0.0;
    _aside += (asideTarget - _aside) * (dt * 7).clamp(0.0, 1.0);
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
    if (StageDirector.duoAnim.playing) return; // the pair is drawn by the director
    // an action animation (dance…) replaces the idle sprite while it plays
    final anim = StageDirector.sebastianAnim;
    final frame = anim.frame;
    if (frame != null && !animator.isFocused) {
      final data = anim.data!;
      paintAnimFrame(canvas, frame, data, size.x, size.y, _animPaint);
      _paintTag(canvas, data.headInBox(anim.frameIndex, size.x, size.y));
      return;
    }
    final pose = animator.pose;

    // Scale around the eye line: he grows towards the camera the way a face
    // does, instead of inflating from the floor.
    final eye = Offset(size.x / 2, size.y * eyeLine);

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
    _paintTag(canvas);
    canvas.restore();
  }

  /// The name sits on top of his head: called inside the body transform (it
  /// sways and breathes with him) or with the head point of an animation frame.
  void _paintTag(Canvas canvas, [Offset? head]) {
    // hidden while he is in the close-up
    final zoom = animator.pose.zoom;
    final opacity = speaking.contains('sebastian') ? 0.0 : (1 - (zoom - 1) * 4).clamp(0.0, 1.0);
    _tag.paint(canvas, (head ?? Offset(size.x / 2, 0)) - const Offset(0, 4), opacity: opacity);
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
    // one talks at a time: Maxito steps back when Sebastián is chosen
    if (_maxitoFocused) MaxitoController.instance.rest();
    if (StageDirector.sebastianAnim.playing) StageDirector.sebastianAnim.stop();
    if (StageDirector.duoAnim.playing) StageDirector.duoAnim.cancel();
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
    final eye = Vector2(size.x / 2, size.y * eyeLine);
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
