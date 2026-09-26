import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Background music: `casa` (cozy lo-fi) by default, `baile` while Sebastián
/// dances. Both are our own loops from `tool/make_music.py`.
///
/// Browsers only allow sound after a user gesture, so [start] is called on the
/// first tap anywhere.
class Music extends ChangeNotifier {
  Music._();

  static final Music instance = Music._();

  AudioPlayer? _player;
  String _track = 'casa';
  bool _started = false;
  bool _muted = false;
  double _volume = 0;
  int _fadeId = 0;

  bool get muted => _muted;
  String get track => _track;

  AudioPlayer get _p => _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);

  /// Loads the default loop, so the first note plays without a gap.
  Future<void> preload() async {
    try {
      await _p.setSource(AssetSource('audio/$_track.mp3'));
    } catch (e) {
      debugPrint('Music: $e');
    }
  }

  /// The music begins (native: at launch; web: on the first touch — a blocked
  /// autoplay is simply retried on the next one).
  Future<void> start() async {
    if (_started || _starting) return;
    _starting = true;
    _started = await _playCurrent();
    _starting = false;
  }

  bool _starting = false;

  /// Switches the loop ('casa' / 'baile').
  Future<void> play(String track) async {
    if (_track == track) return;
    _track = track;
    notifyListeners();
    if (_started) await _playCurrent();
  }

  /// Bedtime: the lullaby comes in from whatever was playing.
  Future<void> night() => fadeTo('noche');

  /// Morning: back to the flat's music.
  Future<void> morning() => fadeTo('casa');

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    if (!_started) return;
    try {
      if (_muted) {
        await _p.pause();
      } else {
        await _playCurrent();
      }
    } catch (e) {
      debugPrint('Music: $e');
    }
  }

  static double _levelOf(String track) => switch (track) {
        'baile' => 0.6,
        'noche' => 0.55,
        _ => 0.5,
      };

  /// Changes the loop smoothly: the current one fades out, the new one fades in.
  Future<void> fadeTo(String track, {Duration out = const Duration(milliseconds: 1800), Duration fadeIn = const Duration(milliseconds: 2600)}) async {
    if (_track == track) return;
    _track = track;
    notifyListeners();
    if (!_started || _muted) return;
    final id = ++_fadeId;
    try {
      await _ramp(0, out, id);
      if (id != _fadeId) return; // another fade took over
      await _p.stop();
      await _p.play(AssetSource('audio/$track.mp3'), volume: 0);
      _volume = 0;
      await _ramp(_levelOf(track), fadeIn, id);
    } catch (e) {
      debugPrint('Music: $e');
    }
  }

  Future<void> _ramp(double to, Duration d, int id) async {
    const steps = 24;
    final from = _volume;
    for (var i = 1; i <= steps; i++) {
      if (id != _fadeId) return;
      _volume = from + (to - from) * i / steps;
      await _p.setVolume(_volume);
      await Future<void>.delayed(d ~/ steps);
    }
  }

  Future<bool> _playCurrent() async {
    if (_muted) return true;
    try {
      await _p.stop();
      _volume = _levelOf(_track);
      await _p.play(AssetSource('audio/$_track.mp3'), volume: _volume);
      return true;
    } catch (e) {
      // no sound is never a reason to break the game (autoplay rules, silent mode…)
      debugPrint('Music: $e');
      return false;
    }
  }
}
