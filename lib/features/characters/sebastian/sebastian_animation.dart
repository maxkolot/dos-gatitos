import 'dart:math' as math;

/// Sebastián's animation states.
///
/// Everyone who wants him to react (dialogue, AI answers, events) only needs
/// this enum plus [SebastianAnimator] / the `Sebastian` helpers in
/// `sebastian_character.dart`. No animation package, no asset states, no
/// external controller required.
enum SebastianAnimationState {
  /// Standing around the flat: breathing, slow head sway, occasional blink.
  idle,

  /// He is being asked something / waiting for the player: eyes on the player,
  /// still body, short attentive blinks.
  listening,

  /// He is answering: head nods with the speech rhythm.
  talking,

  /// Cozy mood: head tilted, sleepy half-lidded eyes, soft breathing.
  affectionate,

  /// Late evening: droopy eyes, long blinks, very slow sway.
  sleepy;

  /// States in which he is talking to the player (close-up, direct gaze).
  bool get isDialogue =>
      this == SebastianAnimationState.listening ||
      this == SebastianAnimationState.talking;

  /// Spanish label — used by debug overlays and by dialogue UI.
  String get labelEs => switch (this) {
    SebastianAnimationState.idle => 'tranquilo',
    SebastianAnimationState.listening => 'escuchando',
    SebastianAnimationState.talking => 'hablando',
    SebastianAnimationState.affectionate => 'cariñoso',
    SebastianAnimationState.sleepy => 'con sueño',
  };
}

/// One frame of Sebastián: everything a renderer needs, already computed.
///
/// Units: [offsetY] in logical pixels of the sprite box, [rotation] in radians,
/// [stretch] a scale multiplier around 1.0, [eyeOpen] and [gaze] and
/// [talkPulse] are 0..1, [zoom] is a scale multiplier (1.0 = standing,
/// [SebastianAnimator.focusZoom] = close-up).
class SebastianPose {
  const SebastianPose({
    this.offsetY = 0,
    this.rotation = 0,
    this.stretch = 1,
    this.eyeOpen = 1,
    this.gaze = 0.25,
    this.talkPulse = 0,
    this.zoom = 1,
    this.zoomProgress = 0,
  });

  static const SebastianPose neutral = SebastianPose();

  final double offsetY;
  final double rotation;
  final double stretch;
  final double eyeOpen;
  final double gaze;
  final double talkPulse;
  final double zoom;
  final double zoomProgress;

  /// True when the eyelid should be drawn (a blink is in progress or the state
  /// keeps the eyes half closed).
  bool get isBlinking => eyeOpen < 0.999;

  bool get isCloseUp => zoomProgress > 0.5;

  SebastianPose copyWith({
    double? offsetY,
    double? rotation,
    double? stretch,
    double? eyeOpen,
    double? gaze,
    double? talkPulse,
    double? zoom,
    double? zoomProgress,
  }) => SebastianPose(
    offsetY: offsetY ?? this.offsetY,
    rotation: rotation ?? this.rotation,
    stretch: stretch ?? this.stretch,
    eyeOpen: eyeOpen ?? this.eyeOpen,
    gaze: gaze ?? this.gaze,
    talkPulse: talkPulse ?? this.talkPulse,
    zoom: zoom ?? this.zoom,
    zoomProgress: zoomProgress ?? this.zoomProgress,
  );

  @override
  String toString() =>
      'SebastianPose(offsetY: ${offsetY.toStringAsFixed(2)}, '
      'rotation: ${rotation.toStringAsFixed(4)}, '
      'stretch: ${stretch.toStringAsFixed(4)}, '
      'eyeOpen: ${eyeOpen.toStringAsFixed(2)}, '
      'gaze: ${gaze.toStringAsFixed(2)}, '
      'talkPulse: ${talkPulse.toStringAsFixed(2)}, '
      'zoom: ${zoom.toStringAsFixed(3)})';
}

/// Generates [SebastianPose]s from a state + elapsed time.
///
/// Pure Dart, no Flutter/Flame import: cheap enough for 60 fps and easy to unit
/// test. Call [update] once per frame with the frame delta, read [pose].
class SebastianAnimator {
  SebastianAnimator({
    int seed = 7,
    this.zoomInDuration = const Duration(milliseconds: 380),
    this.zoomOutDuration = const Duration(milliseconds: 340),
    this.blinkDuration = const Duration(milliseconds: 180),
  }) : _rnd = math.Random(seed);

  /// Close-up move (tap / question): must stay inside 300–500 ms.
  final Duration zoomInDuration;

  /// Step back to his place.
  final Duration zoomOutDuration;

  /// How long a normal blink takes (close + open).
  final Duration blinkDuration;

  /// Scale at the end of the close-up.
  static const double focusZoom = 2.05;

  final math.Random _rnd;

  SebastianAnimationState _state = SebastianAnimationState.idle;
  SebastianAnimationState get state => _state;

  bool _focused = false;

  /// True while he is in the face-to-player close-up (dialogue).
  bool get isFocused => _focused;

  double _time = 0;
  double _stateTime = 0;
  double _zoomT = 0;
  double _gaze = 0.25;
  double _impulse = 0;
  double _blinkTimer = 2;
  double _blinkT = -1;
  double _currentBlink = 0.18;

  SebastianPose _pose = SebastianPose.neutral;

  /// Last computed frame — read it from `update`/`render` of the renderer.
  SebastianPose get pose => _pose;

  /// Seconds spent in the current state.
  double get stateTime => _stateTime;

  /// Eased 0..1 close-up progress (0 = at his place, 1 = face to player).
  double get zoomProgress => _easeInOutCubic(_zoomT);

  // --- public API ----------------------------------------------------------

  /// Switch mood/animation. `idle/listening/talking/affectionate/sleepy`.
  void setState(SebastianAnimationState state) {
    if (state == _state) {
      _stateTime = 0;
      return;
    }
    _state = state;
    _stateTime = 0;
    _scheduleNextBlink();
  }

  /// Starts the close-up: smooth approach (300–500 ms), direct gaze, blinks
  /// and head sway while [listening] (or [talking] if the answer starts now).
  void enterDialogue([
    SebastianAnimationState state = SebastianAnimationState.listening,
  ]) {
    _focused = true;
    setState(state);
    _scheduleNextBlink();
  }

  /// Smoothly returns to his place.
  void exitDialogue() {
    _focused = false;
    setState(SebastianAnimationState.idle);
  }

  void toggleDialogue() => _focused ? exitDialogue() : enterDialogue();

  /// Small reaction to a tap while he is already close to the camera:
  /// a quick blink plus a tiny head tilt.
  void poke() {
    _blinkT = 0;
    _currentBlink = 0.15;
    _impulse = (_rnd.nextDouble() - 0.5) * 0.07;
  }

  /// Advance one frame.
  void update(double dt) {
    if (dt.isNaN || dt.isInfinite || dt <= 0) return;
    // Big pauses (tab in background) must not teleport the animation.
    dt = dt.clamp(0.0, 0.05);

    _time += dt;
    _stateTime += dt;

    // Close-up / step back. Time based, so the move always takes the declared
    // 300–500 ms whatever the frame rate is.
    final speed = _focused
        ? 1000 / math.max(1, zoomInDuration.inMilliseconds)
        : -1000 / math.max(1, zoomOutDuration.inMilliseconds);
    _zoomT = (_zoomT + speed * dt).clamp(0.0, 1.0);
    final zoomProgress = _easeInOutCubic(_zoomT);

    final m = _motion;

    // Gaze: ramps up when he turns to the player, drops in `sleepy`.
    _gaze += (m.gazeBase - _gaze) * math.min(1, dt * 5.5);

    _tickBlink(dt);
    _impulse *= math.max(0, 1 - dt * 4.5);

    final breath = math.sin(_time * m.breathSpeed);
    final sway = math.sin(_time * m.swaySpeed);
    final talkPulse = m.talkSpeed == 0
        ? 0.0
        : 0.5 + 0.5 * math.sin(_time * m.talkSpeed);

    _pose = SebastianPose(
      // Breathing pushes the chest up; when looking at the player he also
      // leans a hair towards the camera.
      offsetY: breath * m.breathAmp - _gaze * 1.2 - talkPulse * m.bobAmp,
      rotation: m.tilt + sway * m.swayAmp + _impulse,
      stretch: 1 + breath * m.breathAmp * 0.008,
      eyeOpen: (m.eyeBase * _blinkCurve).clamp(0.0, 1.0),
      gaze: _gaze.clamp(0.0, 1.0),
      talkPulse: talkPulse,
      zoom: 1 + (focusZoom - 1) * zoomProgress,
      zoomProgress: zoomProgress,
    );
  }

  // --- internals -----------------------------------------------------------

  _Motion get _motion => switch (_state) {
    SebastianAnimationState.idle => const _Motion(
      breathAmp: 1.7,
      breathSpeed: 1.5,
      swayAmp: 0.013,
      swaySpeed: 0.7,
      tilt: 0,
      bobAmp: 0.8,
      talkSpeed: 0,
      gazeBase: 0.25,
      eyeBase: 1,
    ),
    SebastianAnimationState.listening => const _Motion(
      breathAmp: 2.0,
      breathSpeed: 1.25,
      swayAmp: 0.008,
      swaySpeed: 0.6,
      tilt: 0.01,
      bobAmp: 0.4,
      talkSpeed: 0,
      gazeBase: 1,
      eyeBase: 1,
    ),
    SebastianAnimationState.talking => const _Motion(
      breathAmp: 1.4,
      breathSpeed: 2.6,
      swayAmp: 0.022,
      swaySpeed: 1.9,
      tilt: 0,
      bobAmp: 1.6,
      talkSpeed: 9.5,
      gazeBase: 1,
      eyeBase: 1,
    ),
    SebastianAnimationState.affectionate => const _Motion(
      breathAmp: 2.1,
      breathSpeed: 1.1,
      swayAmp: 0.02,
      swaySpeed: 0.8,
      tilt: 0.05,
      bobAmp: 1.0,
      talkSpeed: 0,
      gazeBase: 1,
      eyeBase: 0.72,
    ),
    SebastianAnimationState.sleepy => const _Motion(
      breathAmp: 2.6,
      breathSpeed: 0.9,
      swayAmp: 0.016,
      swaySpeed: 0.5,
      tilt: -0.045,
      bobAmp: 1.2,
      talkSpeed: 0,
      gazeBase: 0.15,
      eyeBase: 0.35,
    ),
  };

  void _tickBlink(double dt) {
    if (_blinkT >= 0) {
      _blinkT += dt;
      if (_blinkT >= _currentBlink) {
        _blinkT = -1;
        // Half of the sleepy blinks come in pairs, like a tired cat.
        final doubleBlink =
            _state == SebastianAnimationState.sleepy && _rnd.nextDouble() < 0.4;
        _scheduleNextBlink(delay: doubleBlink ? 0.14 : null);
      }
      return;
    }
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) {
      _blinkT = 0;
      _currentBlink = _state == SebastianAnimationState.sleepy
          ? blinkDuration.inMilliseconds / 1000 * 1.7
          : blinkDuration.inMilliseconds / 1000;
    }
  }

  void _scheduleNextBlink({double? delay}) {
    if (delay != null) {
      _blinkTimer = delay;
      return;
    }
    final (lo, hi) = switch (_state) {
      SebastianAnimationState.idle => (2.4, 5.8),
      SebastianAnimationState.listening => (1.8, 4.2),
      SebastianAnimationState.talking => (1.3, 3.0),
      SebastianAnimationState.affectionate => (2.6, 6.0),
      SebastianAnimationState.sleepy => (1.0, 2.6),
    };
    _blinkTimer = lo + _rnd.nextDouble() * (hi - lo);
  }

  /// 1 = eyes wide open, 0 = fully closed.
  double get _blinkCurve {
    if (_blinkT < 0) return 1;
    final p = (_blinkT / _currentBlink).clamp(0.0, 1.0);
    return 1 - math.sin(p * math.pi);
  }

  static double _easeInOutCubic(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
  }
}

/// Per-state motion parameters (kept in one place so the feel is tunable).
class _Motion {
  const _Motion({
    required this.breathAmp,
    required this.breathSpeed,
    required this.swayAmp,
    required this.swaySpeed,
    required this.tilt,
    required this.bobAmp,
    required this.talkSpeed,
    required this.gazeBase,
    required this.eyeBase,
  });

  final double breathAmp;
  final double breathSpeed;
  final double swayAmp;
  final double swaySpeed;
  final double tilt;
  final double bobAmp;
  final double talkSpeed;
  final double gazeBase;
  final double eyeBase;
}
