import 'package:flutter/foundation.dart';

/// Maxito's mood. Everything the animation rig shows is driven by this.
enum MaxitoState {
  /// Standing in his corner, breathing, blinking now and then.
  idle,

  /// The player tapped him: he comes to the camera and looks at the player.
  listening,

  /// He is answering — head sways more, the speech bubble is open.
  talking,

  /// Playful mood: bouncing, ears-like sway, sparkles.
  playful,

  /// Sleepy: half-closed eyelids, slow deep breathing.
  sleepy;

  /// True while Maxito is in the close-up in front of the camera.
  bool get isCloseUp =>
      this == listening || this == talking || this == playful;

  /// How much of the eye the resting eyelid covers in this state (0..1).
  double get restingLid => switch (this) {
        MaxitoState.sleepy => 0.55,
        MaxitoState.talking => 0.06,
        MaxitoState.listening => 0.0,
        MaxitoState.idle => 0.0,
        MaxitoState.playful => 0.0,
      };
}

/// The one public API for driving Maxito — used by the tap handler, by the
/// dialogue layer and by anything that wants to show a mood:
///
/// ```dart
/// MaxitoController.instance.focus();            // player tapped him
/// MaxitoController.instance.say('¡Hola, che!'); // talking + speech bubble
/// MaxitoController.instance.state = MaxitoState.playful;
/// MaxitoController.instance.sleep();            // and wake() later
/// MaxitoController.instance.rest();             // smooth return to his spot
/// ```
///
/// A timed state (focus/say with a hold) falls back to [MaxitoState.idle] by
/// itself after the hold ran out, so a forgotten interaction never sticks.
class MaxitoController extends ChangeNotifier {
  MaxitoController();

  /// The live Maxito of the running game.
  static final MaxitoController instance = MaxitoController();

  MaxitoState _state = MaxitoState.idle;

  /// Current mood.
  MaxitoState get state => _state;
  set state(MaxitoState value) => switchTo(value);

  String _line = '';

  /// What he is saying right now ('' = bubble hidden).
  String get line => _line;
  bool get hasLine => _line.isNotEmpty;

  double _hold = 0;

  /// Seconds left until a timed state returns to idle (0 = no timer).
  double get holdSeconds => _hold;

  /// Animated close-up progress, 0 (his spot) .. 1 (in front of the camera).
  /// Written by the animation rig, read by the bubble.
  double zoom = 0;

  /// Where his head is on screen right now — the bubble follows it.
  double headX = 0;
  double headY = 0;
  double headSize = 0;

  /// Player selected Maxito (tap): come closer and listen.
  void focus({double hold = 6}) {
    _hold = hold;
    switchTo(MaxitoState.listening);
  }

  /// He answers: close-up + a line in the bubble.
  void say(String line, {double hold = 8}) {
    _line = line.trim();
    _hold = hold;
    switchTo(MaxitoState.talking);
    notifyListeners();
  }

  /// Playful mood (no timer unless [hold] is given).
  void play({double hold = 0}) {
    _hold = hold;
    switchTo(MaxitoState.playful);
  }

  /// He dozes off where he stands.
  void sleep() {
    _hold = 0;
    _line = '';
    switchTo(MaxitoState.sleepy);
  }

  /// Wakes up into the idle animation.
  void wake() => rest();

  /// Ends any interaction: line cleared, smooth return to his spot.
  void rest() {
    _hold = 0;
    if (_line.isNotEmpty) _line = '';
    switchTo(MaxitoState.idle);
  }

  /// Change the mood (notifies listeners only on a real change).
  void switchTo(MaxitoState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  /// Counts the interaction timer down. Called once per frame by the rig.
  void tick(double dt) {
    if (_hold <= 0) return;
    _hold -= dt;
    if (_hold <= 0) rest();
  }
}
