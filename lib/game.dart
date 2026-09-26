import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'features/features.dart';

/// Main Dos Gatitos Tamagotchi scene. Legacy fish/cat demo removed.
class DosGatitosGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF1D1B2E);

  @override
  Future<void> onLoad() async {
    await addAll(buildFeatures());
  }
}
