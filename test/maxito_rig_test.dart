import 'package:dos_gatitos/features/characters/maxito/maxito.dart';
import 'package:dos_gatitos/game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real game and drives Maxito's rig — catches load/render errors that
/// a unit test of the state machine cannot see.
void main() {
  testWidgets('Maxito loads his sprite and animates', (tester) async {
    final game = DosGatitosGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull, reason: 'game boot must be clean');

    MaxitoCharacter? found;
    for (var i = 0; i < 300 && !(found?.isMounted ?? false); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
      found = game.children.whereType<MaxitoCharacter>().firstOrNull;
    }
    final maxito = found!;
    expect(maxito.isLoaded, isTrue, reason: 'sprite decoded');

    // idle: he stays in his corner and moves a little
    final first = maxito.position.clone();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect((maxito.position - first).length, lessThan(6), reason: 'idle = tiny motion');
    expect(maxito.size.y, greaterThan(100));

    // tap -> close-up: he grows and comes to the middle of the screen
    MaxitoController.instance.focus();
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // ~450 ms of real frames
    }
    expect(tester.takeException(), isNull);
    expect(MaxitoController.instance.zoom, greaterThan(0.9),
        reason: 'zoom-in finishes inside ~400 ms');
    expect(maxito.scale.x, greaterThan(1.8));
    expect(maxito.position.x, closeTo(game.size.x * 0.58, 2)); // right of centre: Sebastián stays tappable
    expect(MaxitoController.instance.headSize, greaterThan(0));

    // bubble follows his head
    MaxitoController.instance.say('¡Hola! ¿Qué tal, che?');
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // return
    MaxitoController.instance.rest();
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(MaxitoController.instance.zoom, lessThan(0.05));
    expect(maxito.scale.x, closeTo(1, 0.02));

    // every mood renders without an exception
    for (final state in MaxitoState.values) {
      MaxitoController.instance.switchTo(state);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: 'state ${state.name} renders');
    }
  });
}
