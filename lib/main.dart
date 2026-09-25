import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() => runApp(GameWidget(game: DosGatitosGame()));

/// Starter: fish fall from the sky, drag to move the ginger cat, the black one follows. Catch = +1.
class DosGatitosGame extends FlameGame with DragCallbacks, TapCallbacks {
  final _rnd = Random();
  late final TextComponent _cat1;
  late final TextComponent _cat2;
  late final TextComponent _score;
  double _targetX = 0;
  double _spawn = 0;
  int score = 0;

  @override
  Color backgroundColor() => const Color(0xFF1D1B2E);

  @override
  Future<void> onLoad() async {
    _targetX = size.x / 2;
    _cat1 = _emoji('🐈', 64)..position = Vector2(size.x / 2, size.y - 60);
    _cat2 = _emoji('🐈‍⬛', 64)..position = Vector2(size.x / 2 - 70, size.y - 60);
    _score = TextComponent(
      text: 'Peces: 0',
      position: Vector2(16, 16),
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    );
    addAll([_cat1, _cat2, _score]);
  }

  TextComponent _emoji(String e, double s) => TextComponent(
        text: e,
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: s)),
      );

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _targetX = event.canvasEndPosition.x;
  }

  @override
  void onTapDown(TapDownEvent event) => _targetX = event.canvasPosition.x;

  @override
  void update(double dt) {
    super.update(dt);
    _cat1.x += (_targetX - _cat1.x) * min(1, dt * 10);
    _cat2.x += (_cat1.x - 70 - _cat2.x) * min(1, dt * 4);

    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = 0.8 + _rnd.nextDouble();
      add(_emoji('🐟', 40)..position = Vector2(20 + _rnd.nextDouble() * (size.x - 40), -20));
    }

    for (final fish in children.whereType<TextComponent>().where((c) => c.text == '🐟').toList()) {
      fish.y += 180 * dt;
      final caught = [_cat1, _cat2].any((cat) => cat.position.distanceTo(fish.position) < 50);
      if (caught) {
        score++;
        _score.text = 'Peces: $score';
      }
      if (caught || fish.y > size.y + 40) fish.removeFromParent();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _cat1.y = size.y - 60;
      _cat2.y = size.y - 60;
    }
  }
}
