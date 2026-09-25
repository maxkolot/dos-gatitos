import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../game.dart';

/// Fish counter in the top-left corner.
class ScoreHud extends TextComponent with HasGameReference<DosGatitosGame> {
  ScoreHud()
      : super(
          text: 'Peces: 0',
          position: Vector2(16, 80),
          textRenderer: TextPaint(style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 24)),
        );

  @override
  Future<void> onLoad() async => game.score.addListener(() => text = 'Peces: ${game.score.value}');
}
