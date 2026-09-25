import 'dart:math';

import 'package:flame/components.dart';

import '../game.dart';

/// Fish fall from the sky; a cat that touches one catches it (+1).
class FishRain extends Component with HasGameReference<DosGatitosGame> {
  final _rnd = Random();
  late final Sprite _fish;
  double _spawn = 0;

  @override
  Future<void> onLoad() async => _fish = await game.loadSprite('fish.png');

  @override
  void update(double dt) {
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = 0.8 + _rnd.nextDouble();
      add(SpriteComponent(
        sprite: _fish,
        size: Vector2.all(44),
        anchor: Anchor.center,
        position: Vector2(20 + _rnd.nextDouble() * (game.size.x - 40), -20),
      ));
    }
    for (final fish in children.whereType<SpriteComponent>().toList()) {
      fish.y += 180 * dt;
      final caught = game.cats.all.any((cat) => cat.position.distanceTo(fish.position) < 50);
      if (caught) game.score.value++;
      if (caught || fish.y > game.size.y + 40) fish.removeFromParent();
    }
  }
}
