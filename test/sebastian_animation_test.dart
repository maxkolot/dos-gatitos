import 'package:flutter_test/flutter_test.dart';

import 'package:dos_gatitos/features/characters/sebastian/sebastian_animation.dart';

/// Runs the animator for [seconds] at a fixed frame rate and collects poses.
List<SebastianPose> run(
  SebastianAnimator a,
  double seconds, {
  double step = 1 / 60,
}) {
  final frames = <SebastianPose>[];
  var t = 0.0;
  while (t < seconds) {
    a.update(step);
    frames.add(a.pose);
    t += step;
  }
  return frames;
}

void main() {
  group('idle', () {
    test('starts standing, no zoom, eyes open', () {
      final a = SebastianAnimator();
      expect(a.state, SebastianAnimationState.idle);
      expect(a.isFocused, isFalse);
      expect(a.pose.zoom, 1.0);
      expect(a.pose.zoomProgress, 0.0);
      expect(a.pose.eyeOpen, 1.0);
    });

    test('breathes: offset moves and stays subtle', () {
      final a = SebastianAnimator();
      final frames = run(a, 5);
      final offsets = frames.map((p) => p.offsetY).toList();
      expect(offsets.reduce((x, y) => x > y ? x : y) -
          offsets.reduce((x, y) => x < y ? x : y), greaterThan(1.0));
      for (final o in offsets) {
        expect(o.abs(), lessThan(6));
      }
    });

    test('sways its head', () {
      final a = SebastianAnimator();
      final frames = run(a, 6);
      final rotations = frames.map((p) => p.rotation).toList();
      expect(rotations.any((r) => r.abs() > 0.004), isTrue);
      for (final r in rotations) {
        expect(r.abs(), lessThan(0.2));
      }
    });

    test('blinks within a few seconds and the eyes come back', () {
      final a = SebastianAnimator();
      final frames = run(a, 8);
      expect(frames.any((p) => p.eyeOpen < 0.4), isTrue,
          reason: 'a blink should happen inside 8 s');
      expect(frames.last.eyeOpen, greaterThan(0.9));
    });

    test('is deterministic for the same seed', () {
      final a = SebastianAnimator(seed: 3);
      final b = SebastianAnimator(seed: 3);
      final fa = run(a, 6);
      final fb = run(b, 6);
      for (var i = 0; i < fa.length; i++) {
        expect(fa[i].eyeOpen, fb[i].eyeOpen);
        expect(fa[i].rotation, fb[i].rotation);
      }
    });
  });

  group('close-up', () {
    test('reaches full zoom in 300–500 ms', () {
      final a = SebastianAnimator();
      a.enterDialogue();
      expect(a.isFocused, isTrue);
      expect(a.state, SebastianAnimationState.listening);
      run(a, 0.2);
      expect(a.pose.zoom, greaterThan(1.05));
      expect(a.pose.zoom, lessThan(SebastianAnimator.focusZoom),
          reason: 'zoom must not be finished after 200 ms');
      run(a, 0.4); // 600 ms total
      expect(a.pose.zoom, closeTo(SebastianAnimator.focusZoom, 0.001));
      expect(a.pose.zoomProgress, 1.0);
    });

    test('zoom is monotonic (smooth approach, no jumps)', () {
      final a = SebastianAnimator();
      a.enterDialogue();
      final frames = run(a, 1);
      for (var i = 1; i < frames.length; i++) {
        expect(frames[i].zoom, greaterThanOrEqualTo(frames[i - 1].zoom));
        // Peak speed of a 380 ms move is ~0.14 scale per 60 fps frame —
        // a real jump would be a whole ~1.0 step.
        expect(frames[i].zoom - frames[i - 1].zoom, lessThan(0.15));
      }
    });

    test('looks straight at the player', () {
      final a = SebastianAnimator();
      a.enterDialogue();
      run(a, 1);
      expect(a.pose.gaze, closeTo(1, 0.02));
    });

    test('steps back smoothly when the dialogue ends', () {
      final a = SebastianAnimator();
      a.enterDialogue(SebastianAnimationState.talking);
      run(a, 1);
      a.exitDialogue();
      expect(a.state, SebastianAnimationState.idle);
      expect(a.isFocused, isFalse);
      run(a, 0.2);
      expect(a.pose.zoom, lessThan(SebastianAnimator.focusZoom));
      run(a, 0.4);
      expect(a.pose.zoom, closeTo(1, 0.001));
    });

    test('tapping again pokes a blink and a small tilt', () {
      final a = SebastianAnimator();
      a.enterDialogue();
      a.poke();
      final frames = run(a, 0.2);
      expect(frames.first.eyeOpen, lessThan(0.9));
      expect(frames.any((p) => p.rotation.abs() > 0.01), isTrue);
    });
  });

  group('states', () {
    test('every state animates within sane bounds', () {
      for (final state in SebastianAnimationState.values) {
        final a = SebastianAnimator();
        a.setState(state);
        expect(a.state, state);
        final frames = run(a, 6);
        for (final p in frames) {
          expect(p.offsetY.abs(), lessThan(8));
          expect(p.rotation.abs(), lessThan(0.2));
          expect(p.stretch, greaterThan(0.95));
          expect(p.stretch, lessThan(1.05));
          expect(p.eyeOpen, inInclusiveRange(0, 1));
          expect(p.gaze, inInclusiveRange(0, 1));
          expect(p.zoom, 1.0);
        }
        expect(frames.any((p) => p.eyeOpen < 0.99), isTrue,
            reason: '$state should blink or keep half closed eyes');
      }
    });

    test('talking nods more than listening', () {
      final listening = SebastianAnimator()..setState(SebastianAnimationState.listening);
      final talking = SebastianAnimator()..setState(SebastianAnimationState.talking);
      double amp(SebastianAnimator a) {
        final r = run(a, 6).map((p) => p.rotation).toList();
        final max = r.reduce((x, y) => x > y ? x : y);
        final min = r.reduce((x, y) => x < y ? x : y);
        return max - min;
      }

      expect(amp(talking), greaterThan(amp(listening)));
    });

    test('talking exposes a speech pulse', () {
      final a = SebastianAnimator();
      a.enterDialogue(SebastianAnimationState.talking);
      final frames = run(a, 1);
      expect(frames.map((p) => p.talkPulse).reduce((x, y) => x > y ? x : y),
          greaterThan(0.9));
      expect(frames.map((p) => p.talkPulse).reduce((x, y) => x < y ? x : y),
          lessThan(0.1));
    });

    test('sleepy keeps the eyes droopy and looks away', () {
      final a = SebastianAnimator()..setState(SebastianAnimationState.sleepy);
      run(a, 4);
      expect(a.pose.gaze, lessThan(0.5));
      final open = run(a, 0.5).map((p) => p.eyeOpen).toList();
      expect(open.reduce((x, y) => x > y ? x : y), lessThan(0.6));
    });

    test('affectionate tilts the head to one side', () {
      final a = SebastianAnimator()..setState(SebastianAnimationState.affectionate);
      final frames = run(a, 4);
      final avg = frames.map((p) => p.rotation).reduce((x, y) => x + y) /
          frames.length;
      expect(avg, greaterThan(0.02));
    });

    test('huge dt (backgrounded tab) does not teleport the pose', () {
      final a = SebastianAnimator();
      a.enterDialogue();
      a.update(5);
      expect(a.pose.zoom, lessThan(SebastianAnimator.focusZoom));
    });
  });
}
