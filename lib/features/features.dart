import 'package:flame/components.dart';

import 'characters/sebastian/sebastian_character.dart';
import 'title_banner.dart';

/// Active components of the current Dos Gatitos Tamagotchi.
/// Legacy Cats/FishRain/ScoreHud demo components are intentionally removed.
List<Component> buildFeatures() => [SebastianCharacter(), TitleBanner()];
