import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../game.dart';

/// Game name at the top, read from app.json — the single place to rename the game
/// (the deploy also puts it on the iPhone home screen and the browser tab).
class TitleBanner extends PositionComponent with HasGameReference<DosGatitosGame> {
  final _title = TextComponent(
    anchor: Anchor.topCenter,
    textRenderer: TextPaint(style: const TextStyle(color: Color(0xFFFFB02E), fontSize: 28, fontWeight: FontWeight.w700)),
  );
  final _subtitle = TextComponent(
    anchor: Anchor.topCenter,
    textRenderer: TextPaint(style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 16)),
  );

  @override
  Future<void> onLoad() async {
    final app = jsonDecode(await rootBundle.loadString('app.json')) as Map<String, dynamic>;
    _title.text = app['name'] as String? ?? '';
    _subtitle.text = app['subtitle'] as String? ?? '';
    addAll([_title, _subtitle]);
  }

  @override
  void update(double dt) {
    _title.position = Vector2(game.size.x / 2, 12);
    _subtitle.position = Vector2(game.size.x / 2, 46);
  }
}
