import 'dart:math';

enum _Stage { waiting, closing, opening }

/// Maxito's blink rhythm: irregular gaps (2.2–5.6 s), a quick close/open and
/// now and then a small double blink, so he never looks like a metronome.
///
/// Pure logic (no Flutter import) so it can be unit tested with a seeded
/// [Random].
class MaxitoBlink {
  MaxitoBlink({Random? random}) : _random = random ?? Random() {
    _gap = _minGap;
  }

  final Random _random;

  static const double _closeTime = 0.06;
  static const double _openTime = 0.08;
  static const double _minGap = 2.2;
  static const double _maxGap = 5.6;
  static const double _doubleGap = 0.10;
  static const double _doubleChance = 0.22;

  _Stage _stage = _Stage.waiting;
  double _gap = _minGap;
  double _timer = 0;
  double _closed = 0;

  /// How much of the eye the eyelid covers right now (0 open .. 1 closed).
  double get closedAmount => _closed;

  /// 1 = eyes wide open, 0 = eyes shut.
  double get openness => 1 - _closed;

  bool get isBlinking => _stage != _Stage.waiting;

  /// Blinks on the next frame (used when Maxito gets tapped / surprised).
  void blinkNow() {
    if (isBlinking) return;
    _stage = _Stage.closing;
    _timer = 0;
    _closed = 0;
  }

  /// Advance the rhythm by [dt] seconds.
  void update(double dt) {
    var remaining = dt;
    // The loop carries the leftover time into the next stage, so a long frame
    // (app paused, browser tab in background) cannot break the rhythm.
    var guard = 0;
    while (remaining > 0 && guard++ < 1000) {
      switch (_stage) {
        case _Stage.waiting:
          if (_gap > remaining) {
            _gap -= remaining;
            remaining = 0;
          } else {
            remaining -= _gap;
            _gap = 0;
            _stage = _Stage.closing;
            _timer = 0;
          }
        case _Stage.closing:
          final left = _closeTime - _timer;
          if (left > remaining) {
            _timer += remaining;
            remaining = 0;
          } else {
            remaining -= left;
            _timer = 0;
            _stage = _Stage.opening;
          }
        case _Stage.opening:
          final left = _openTime - _timer;
          if (left > remaining) {
            _timer += remaining;
            remaining = 0;
          } else {
            remaining -= left;
            _timer = 0;
            _stage = _Stage.waiting;
            _gap = _nextGap();
          }
      }
    }
    _closed = _closedForStage();
  }

  double _closedForStage() => switch (_stage) {
        _Stage.closing => (_timer / _closeTime).clamp(0.0, 1.0),
        _Stage.opening => 1 - (_timer / _openTime).clamp(0.0, 1.0),
        _Stage.waiting => 0,
      };

  double _nextGap() {
    if (_random.nextDouble() < _doubleChance) return _doubleGap;
    return _minGap + _random.nextDouble() * (_maxGap - _minGap);
  }
}
