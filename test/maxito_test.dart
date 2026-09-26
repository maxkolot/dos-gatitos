import 'dart:math';

import 'package:dos_gatitos/features/characters/maxito/maxito.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaxitoController (state API)', () {
    late MaxitoController c;

    setUp(() => c = MaxitoController());

    test('starts idle, not in close-up', () {
      expect(c.state, MaxitoState.idle);
      expect(c.state.isCloseUp, isFalse);
      expect(c.hasLine, isFalse);
    });

    test('focus -> listening, close-up, auto-return after the hold', () {
      var notifications = 0;
      c.addListener(() => notifications++);
      c.focus(hold: 3);
      expect(c.state, MaxitoState.listening);
      expect(c.state.isCloseUp, isTrue);

      c.tick(2.9);
      expect(c.state, MaxitoState.listening);
      c.tick(0.2);
      expect(c.state, MaxitoState.idle, reason: 'hold ran out -> back to his spot');
      expect(notifications, 2);
    });

    test('say -> talking + line, rest clears the line', () {
      c.say('  ¡Hola, che!  ', hold: 5);
      expect(c.state, MaxitoState.talking);
      expect(c.line, '¡Hola, che!');
      expect(c.hasLine, isTrue);
      c.rest();
      expect(c.state, MaxitoState.idle);
      expect(c.hasLine, isFalse);
    });

    test('playful and sleepy are sticky (no timer)', () {
      c.play();
      c.tick(30);
      expect(c.state, MaxitoState.playful);
      c.sleep();
      c.tick(30);
      expect(c.state, MaxitoState.sleepy);
      c.wake();
      expect(c.state, MaxitoState.idle);
    });

    test('same state does not notify twice', () {
      var notifications = 0;
      c.addListener(() => notifications++);
      c.switchTo(MaxitoState.idle);
      expect(notifications, 0);
      c.switchTo(MaxitoState.playful);
      c.switchTo(MaxitoState.playful);
      expect(notifications, 1);
    });

    test('resting lid: sleepy keeps the eyes half closed', () {
      expect(MaxitoState.sleepy.restingLid, greaterThan(0.4));
      expect(MaxitoState.idle.restingLid, 0);
      expect(MaxitoState.idle.isCloseUp, isFalse);
      expect(MaxitoState.talking.isCloseUp, isTrue);
    });
  });

  group('MaxitoBlink', () {
    test('blinks within a few seconds and closes the eyes fully', () {
      final blink = MaxitoBlink(random: Random(7));
      var minOpenness = 1.0;
      var blinks = 0;
      var wasOpen = true;
      for (var i = 0; i < 60 * 8; i++) {
        blink.update(1 / 60);
        minOpenness = min(minOpenness, blink.openness);
        expect(blink.openness, inInclusiveRange(0.0, 1.0));
        if (blink.isBlinking && wasOpen) blinks++;
        wasOpen = !blink.isBlinking;
      }
      expect(minOpenness, lessThan(0.02), reason: 'the eyes must really close');
      expect(blinks, greaterThanOrEqualTo(1));
      expect(blinks, lessThanOrEqualTo(5), reason: 'not a metronome');
    });

    test('blinkNow triggers immediately', () {
      final blink = MaxitoBlink(random: Random(1));
      blink.blinkNow();
      expect(blink.isBlinking, isTrue);
      blink.update(0.06);
      expect(blink.closedAmount, greaterThan(0.9));
      for (var i = 0; i < 12; i++) {
        blink.update(1 / 60);
      }
      expect(blink.openness, greaterThan(0.9), reason: 'opens again quickly');
    });

    test('a long frame (tab in background) does not break the rhythm', () {
      final blink = MaxitoBlink(random: Random(3));
      for (var i = 0; i < 40; i++) {
        blink.update(0.5);
        expect(blink.openness, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  test('Maxito sprite asset ships with the game', () async {
    final data = await rootBundle.load(MaxitoCharacter.assetPath);
    expect(data.lengthInBytes, greaterThan(5000));
  });
}
