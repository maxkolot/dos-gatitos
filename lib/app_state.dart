import 'dart:async';

import 'features/tamagotchi/tamagotchi.dart';

/// The one Tamagotchi of the running app: stats of both, actions, saving.
/// The HUD listens to it, the stage director drives its drift and actions.
final TamagotchiLoop tamagotchi = TamagotchiLoop();

/// Completed by the game when the room and both characters (with their
/// animations) are loaded — the splash waits for it.
final Completer<void> gameLoaded = Completer<void>();
