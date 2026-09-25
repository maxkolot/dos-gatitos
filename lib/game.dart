import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'cats.dart';
import 'features/features.dart';

/// The shared game: two cats + every feature from features/features.dart.
/// Keep this file small — new gameplay goes into its own file under lib/features/.
class DosGatitosGame extends FlameGame with DragCallbacks, TapCallbacks {
  late final Cats cats;

  /// Fish caught — features read and change it, the HUD shows it.
  final score = ValueNotifier<int>(0);

  @override
  Color backgroundColor() => const Color(0xFF1D1B2E);

  @override
  Future<void> onLoad() async {
    cats = Cats();
    await add(cats);
    await addAll(buildFeatures());
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    cats.targetX = event.canvasEndPosition.x;
  }

  @override
  void onTapDown(TapDownEvent event) => cats.targetX = event.canvasPosition.x;
}
