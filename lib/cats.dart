import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'game.dart';

TextComponent emoji(String e, double size) => Emoji(e, size);

/// Emoji as a game object. On the web the color-emoji font arrives a moment after start, and text laid out
/// before that stays an empty box — so for the first seconds the glyph is laid out again until the font is there.
class Emoji extends TextComponent {
  Emoji(String e, double size)
      : super(text: e, anchor: Anchor.center, textRenderer: TextPaint(style: TextStyle(fontSize: size)));

  double _age = 0;
  double _next = 0.3;

  @override
  void update(double dt) {
    super.update(dt);
    if (_next < 0) return;
    _age += dt;
    if (_age >= _next) {
      final t = text;
      text = '';
      text = t;
      _next = _age < 8 ? _age + 0.5 : -1;
    }
  }
}

/// The two heroes: the ginger cat goes where you drag/tap, the black one follows.
class Cats extends Component with HasGameReference<DosGatitosGame> {
  final ginger = emoji('🐈', 64);
  final black = emoji('🐈‍⬛', 64);
  double targetX = 0;

  List<TextComponent> get all => [ginger, black];

  @override
  Future<void> onLoad() async {
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
