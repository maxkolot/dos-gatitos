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
  bool _night = false;

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

  /// They sleep: silence until the morning.
  Future<void> pauseForNight() async {
    _night = true;
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('Music: $e');
    }
  }

  Future<void> resumeAfterNight() async {
    _night = false;
    _track = 'casa';
    notifyListeners();
    if (_started) await _playCurrent();
  }

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

  Future<bool> _playCurrent() async {
    if (_muted || _night) return true;
    try {
      await _p.stop();
      await _p.play(AssetSource('audio/$_track.mp3'), volume: _track == 'baile' ? 0.6 : 0.5);
      return true;
    } catch (e) {
      // no sound is never a reason to break the game (autoplay rules, silent mode…)
      debugPrint('Music: $e');
      return false;
    }
  }
}
