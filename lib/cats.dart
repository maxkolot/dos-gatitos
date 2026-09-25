import 'dart:math';

import 'package:flame/components.dart';

import 'game.dart';

/// A sprite from assets/images/ (make one from an emoji: python3 tool/sprite.py --emoji "🐟" --out assets/images/fish.png).
/// Don't draw emoji as text — the web build can miss their glyphs and shows empty boxes.
Future<SpriteComponent> sprite(DosGatitosGame game, String file, double size) async =>
    SpriteComponent(sprite: await game.loadSprite(file), size: Vector2.all(size), anchor: Anchor.center);

/// The two heroes: the ginger cat goes where you drag/tap, the black one follows.
class Cats extends Component with HasGameReference<DosGatitosGame> {
  late final SpriteComponent ginger;
  late final SpriteComponent black;
  double targetX = 0;

  List<PositionComponent> get all => [ginger, black];

  @override
  Future<void> onLoad() async {
    ginger = await sprite(game, 'cat_ginger.png', 72);
    black = await sprite(game, 'cat_black.png', 72);
    targetX = game.size.x / 2;
    ginger.position = Vector2(game.size.x / 2, game.size.y - 60);
    black.position = Vector2(game.size.x / 2 - 70, game.size.y - 60);
    addAll(all);
  }

  @override
  void update(double dt) {
    ginger.x += (targetX - ginger.x) * min(1, dt * 10);
    black.x += (ginger.x - 70 - black.x) * min(1, dt * 4);
    ginger.y = black.y = game.size.y - 60;
  }
}
