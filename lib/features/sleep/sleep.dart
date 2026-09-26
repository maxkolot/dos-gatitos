import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_state.dart';
import '../audio/music.dart';
import '../audio/sfx.dart';
import '../tamagotchi/tamagotchi.dart';

enum SleepPhase { awake, cinematic, sleeping }

/// Bedtime: the night cinematic, then 8 hours of sleep with a countdown.
/// The wake-up time is saved, so closing the app does not wake them.
class Sleep extends ChangeNotifier {
  Sleep._();

  static final Sleep instance = Sleep._();

  static const Duration night = Duration(hours: 8);
  static const String _key = 'dos_gatitos.sleep_until';

  SleepPhase _phase = SleepPhase.awake;
  DateTime? _until;
  Timer? _tick;

  /// Called on wake-up (the stage says good morning).
  VoidCallback? onWake;

  SleepPhase get phase => _phase;
  bool get active => _phase != SleepPhase.awake;
  DateTime? get until => _until;

  Duration get remaining {
    final u = _until;
    if (u == null) return Duration.zero;
    final left = u.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// App start: still asleep → straight to the countdown; the night is over → they wake up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_key);
      if (ms == null) return;
      _until = DateTime.fromMillisecondsSinceEpoch(ms);
      if (remaining > Duration.zero) {
        _phase = SleepPhase.sleeping;
        _startTick();
        unawaited(Music.instance.night());
        unawaited(Sfx.instance.loop('night@0.8', fade: 2));
        notifyListeners();
      } else {
        await wake();
      }
    } catch (e) {
      debugPrint('Sleep: $e');
    }
  }

  /// «Dormir»: the night cinematic starts, the 8 hours start counting.
  Future<void> start() async {
    if (active) return;
    if (wish.value == TamagotchiAction.dormir) wish.value = null;
    _until = DateTime.now().add(night);
    _phase = SleepPhase.cinematic;
    notifyListeners();
    unawaited(Music.instance.night());
    try {
      (await SharedPreferences.getInstance()).setInt(_key, _until!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Sleep: $e');
    }
  }

  /// The cinematic has faded to black: the countdown screen.
  void cinematicDone() {
    if (_phase != SleepPhase.cinematic) return;
    _phase = SleepPhase.sleeping;
    _startTick();
    notifyListeners();
  }

  /// Morning (or «Saltar»): back to the flat, rested.
  Future<void> wake() async {
    _tick?.cancel();
    _tick = null;
    final slept = _until == null ? night : night - remaining;
    _until = null;
    _phase = SleepPhase.awake;
    try {
      (await SharedPreferences.getInstance()).remove(_key);
    } catch (e) {
      debugPrint('Sleep: $e');
    }
    // a full night gives the whole rest; skipping early still counts a bit
    if (slept >= const Duration(minutes: 30) || slept == night) {
      tamagotchi.activar(TamagotchiAction.dormir);
    }
    unawaited(Music.instance.morning());
    unawaited(Sfx.instance.stopLoop('night', fade: 1.5));
    unawaited(Sfx.instance.play('birds', delay: 0.6)); // good morning, Gràcia
    notifyListeners();
    onWake?.call();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining == Duration.zero) {
        wake();
      } else {
        notifyListeners();
      }
    });
  }
}
