# Sebastián — interaction & animation (role R15)

Owns **Sebastián only**: his sprite, his idle/close-up animation and the tap
that brings him to the camera. Maxito and the AI/dialogue code are other roles.

## Files

| File | What |
| --- | --- |
| `sebastian_animation.dart` | `SebastianAnimationState`, `SebastianPose`, `SebastianAnimator` — pure Dart, no Flutter/Flame, unit tested. |
| `sebastian_character.dart` | `SebastianCharacter` (Flame component: sprite, blinks, close-up) + `Sebastian` global helpers. |
| `assets/characters/sebastian/sebastian_idle.png` | eyes open frame |
| `assets/characters/sebastian/sebastian_blink.png` | eyes closed frame (crossfaded during a blink) |

## State API (Spanish moods, code in English)

```dart
import 'package:dos_gatitos/features/characters/sebastian/sebastian_character.dart';

Sebastian.idle();          // breathing, sway, random blinks
Sebastian.listen();        // smooth approach + direct gaze (close-up, "escuchando")
Sebastian.talk();          // he answers: head nods with the speech rhythm
Sebastian.affectionate();  // head tilted, half-closed eyes, cozy
Sebastian.sleepy();        // late evening: droopy eyes, long blinks
Sebastian.exitDialogue();  // smooth step back to his place
Sebastian.poke();          // small reaction to a tap
```

Read-only: `Sebastian.state`, `Sebastian.isFocused`, `Sebastian.zoom`.
The dialogue UI can hook `SebastianCharacter.onCloseUpChanged` to know when he is
in front of the camera.

Low level (own renderer/frame driver):

```dart
final animator = SebastianAnimator(seed: 1);
animator.enterDialogue(SebastianAnimationState.listening);
animator.update(dt); // once per frame
final pose = animator.pose; // offsetY, rotation, stretch, eyeOpen, gaze, talkPulse, zoom
```

## Timing / performance

* close-up approach **380 ms**, step back **340 ms** (inside the required 300–500 ms), eased in/out.
* blinks 180 ms every 1.3–5.8 s depending on mood; `sleepy` blinks in pairs and slower.
* no animation package, no per-frame allocations of sprites: two cached sprites,
  one `Sprite.render` per frame (+ one `saveLayer` only while an eyelid crossfades).
* state parameters live in one place (`_Motion` in `sebastian_animation.dart`).
* a huge `dt` (backgrounded tab) is clamped to 50 ms, so nothing teleports.

## Tests

`flutter test test/sebastian_animation_test.dart` — 16 tests: breathing/sway
bounds, blink timing, 300–500 ms zoom, monotonic approach, gaze, step back,
per-state feel, determinism, big-dt safety.
