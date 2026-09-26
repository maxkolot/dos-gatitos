import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'music.dart';

/// Sound effects (ours, from `tool/make_sfx.py`): one-shots with [play] and
/// ambience loops (sizzle, vinyl crackle, night) with [loop] / [stopLoop].
///
/// A cue string may carry a volume: `'clink@0.6'`. The music's mute button
/// silences everything. No sound is never a reason to break the game, so every
/// failure is only logged.
class Sfx {
  Sfx._() {
    Music.instance.addListener(() {
      if (Music.instance.muted) stopAllLoops(fade: 0);
    });
  }

  static final Sfx instance = Sfx._();

  static const _maxPerSound = 3;

  /// All effects sit well under the music.
  static const double master = 0.45;
  final Map<String, List<AudioPlayer>> _pool = <String, List<AudioPlayer>>{};
  final Map<String, AudioPlayer> _loops = {};
  final Map<String, int> _loopIds = {};
  final _rnd = math.Random();

  /// Off in tests (no audio plugin there); `main()` turns it on.
  bool enabled = false;

  bool get _muted => !enabled || Music.instance.muted;

  /// Native: copies the sounds heard in the first seconds out of the bundle
  /// ahead of time (the browser simply fetches each small file on first use).
  Future<void> warmUp() async {
    if (kIsWeb || !enabled) return;
    try {
      await AudioCache.instance.loadAll([
        for (final n in const ['ui_tap', 'ui_open', 'sparkle', 'wish', 'voice_seb_1', 'voice_seb_2', 'voice_max_1', 'voice_max_2', 'fer_chirp_1', 'fer_rustle', 'fer_step'])
          'sfx/$n.mp3',
      ]);
    } catch (e) {
      debugPrint('Sfx warm-up: $e');
    }
  }

  /// `'name'` or `'name@0.5'`.
  static (String, double) parse(String cue) {
    final at = cue.indexOf('@');
    if (at < 0) return (cue, 1);
    return (cue.substring(0, at), double.tryParse(cue.substring(at + 1)) ?? 1);
  }

  /// A one-shot. [variants] > 1 picks `name_1..name_N` at random.
  Future<void> play(String cue, {double volume = 1, int variants = 1, double delay = 0}) async {
    if (_muted) return;
    var (name, v) = parse(cue);
    if (variants > 1) name = '${name}_${1 + _rnd.nextInt(variants)}';
    if (delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: (delay * 1000).round()));
      if (_muted) return;
    }
    try {
      final pool = _pool.putIfAbsent(name, () => []);
      AudioPlayer? p;
      for (final q in pool) {
        if (q.state != PlayerState.playing) {
          p = q;
          break;
        }
      }
      if (p == null) {
        if (pool.length < _maxPerSound) {
          p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
          pool.add(p);
        } else {
          p = pool.removeAt(0); // the oldest one gives way
          pool.add(p);
          await p.stop();
        }
      }
      await p.play(AssetSource('sfx/$name.mp3'), volume: (v * volume * master).clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Sfx $name: $e');
    }
  }

  /// Starts an ambience loop (fades in). Calling it again for a running loop does nothing.
  Future<void> loop(String cue, {double volume = 1, double fade = 0.4}) async {
    final (name, v) = parse(cue);
    if (_muted || _loops.containsKey(name)) return;
    final id = (_loopIds[name] ?? 0) + 1;
    _loopIds[name] = id;
    final p = AudioPlayer();
    _loops[name] = p;
    try {
      await p.setReleaseMode(ReleaseMode.loop);
      final target = (v * volume * master).clamp(0.0, 1.0);
      await p.play(AssetSource('sfx/$name.mp3'), volume: fade > 0 ? 0 : target);
      if (fade > 0) await _ramp(p, 0, target, fade, () => _loopIds[name] == id);
    } catch (e) {
      debugPrint('Sfx loop $name: $e');
    }
  }

  /// Fades a loop out and lets it go.
  Future<void> stopLoop(String name, {double fade = 0.6}) async {
    name = parse(name).$1;
    final p = _loops.remove(name);
    if (p == null) return;
    _loopIds[name] = (_loopIds[name] ?? 0) + 1;
    try {
      if (fade > 0) await _ramp(p, p.volume, 0, fade, () => true);
      await p.stop();
      await p.dispose();
    } catch (e) {
      debugPrint('Sfx stop $name: $e');
    }
  }

  void stopAllLoops({double fade = 0.6}) {
    for (final name in _loops.keys.toList()) {
      unawaited(stopLoop(name, fade: fade));
    }
  }

  /// Runs a cue from an animation or a script: `name`, `name@vol`,
  /// `name@vol+delay`, `loop:name@vol` or `stop:name`.
  void cue(String c) {
    if (c.startsWith('loop:')) {
      unawaited(loop(c.substring(5)));
    } else if (c.startsWith('stop:')) {
      unawaited(stopLoop(c.substring(5)));
    } else {
      final plus = c.lastIndexOf('+');
      final delay = plus > 0 ? double.tryParse(c.substring(plus + 1)) ?? 0.0 : 0.0;
      unawaited(play(plus > 0 ? c.substring(0, plus) : c, delay: delay));
    }
  }

  Future<void> _ramp(AudioPlayer p, double from, double to, double seconds, bool Function() alive) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      if (!alive()) return;
      await p.setVolume(from + (to - from) * i / steps);
      await Future<void>.delayed(Duration(milliseconds: (seconds * 1000 / steps).round()));
    }
  }
}
