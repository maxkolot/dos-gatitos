import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'features/tamagotchi/tamagotchi.dart';

/// The one Tamagotchi of the running app: stats of both, actions, saving.
/// The HUD listens to it, the stage director drives its drift and actions.
final TamagotchiLoop tamagotchi = TamagotchiLoop();

/// Completed by the game when the room and both characters (with their
/// animations) are loaded — the splash waits for it.
final Completer<void> gameLoaded = Completer<void>();

/// Bottom of the HUD header (logo + stats) on screen: close-ups and speech
/// bubbles stay below it. Measured by the HUD; 0 until the first layout.
double hudBottom = 0;

/// What the characters are asking for right now — the HUD makes that button glow.
final ValueNotifier<TamagotchiAction?> wish = ValueNotifier(null);

/// The camera close to Sr. Fer asleep (0..1, eased) and the point it looks at
/// (game coordinates). The two step aside while it is on.
final ValueNotifier<double> petZoom = ValueNotifier(0);
Offset petFocus = Offset.zero;

/// Sebastián dances: the two step back into the room (0..1, eased) and Sr. Fer
/// dances between them.
double stageBack = 0;

/// Who has a speech bubble on screen ('sebastian' / 'maxito'): their name tag steps back.
final Set<String> speaking = {};
