import 'package:dos_gatitos/features/minigame/chicken_game.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays a whole round frame by frame: chickens spawn, run, hop and panic, a leap
/// catches, the round ends — and nothing throws on the way.
void main() {
  testWidgets('a round of «Atrapá las gallinas»', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final game = ChickenGame(roundSeconds: 12);
    int? finalScore;
    game.onRoundOver = (s) => finalScore = s;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    for (var i = 0; i < 300 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.isLoaded, isTrue, reason: 'sprites decoded');
    expect(game.floorY, inExclusiveRange(844 * 0.6, 844.0), reason: 'the terrace is on screen');

    game.startRound();
    expect(game.running.value, isTrue);

    // three seconds of play: chickens must appear
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    final before = game.score.value;

    // a landing right under a chicken catches it
    final chickens = game.children.where((c) => c.runtimeType.toString() == '_Chicken').cast<PositionComponent>().toList();
    expect(chickens, isNotEmpty, reason: 'chickens spawned');
    // a hopping chicken cannot be caught (by design): try them until one is on the ground
    for (final c in chickens) {
      if (game.score.value > before) break;
      game.landedAt(c.position.x, 60);
    }
    expect(game.score.value, greaterThan(before));

    // play on until the time is up
    for (var i = 0; i < 12 * 60 + 30 && game.running.value; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(game.running.value, isFalse, reason: 'the round ended');
    expect(finalScore, isNotNull);
  });
}
