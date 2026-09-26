import 'package:flame/components.dart';

import 'characters/sebastian/sebastian_character.dart';
import 'title_banner.dart';

/// Active components of the current Dos Gatitos Tamagotchi.
/// Legacy Cats/FishRain/ScoreHud demo components are intentionally removed.
List<Component> buildFeatures() => [SebastianCharacter(), TitleBanner()];
import 'fish_rain.dart';
import 'room/room_scene.dart';
import 'score_hud.dart';
import 'title_banner.dart';

/// Every feature is one Component in its own file in this folder.
/// Adding one = ONE import line + ONE list line (this file merges line by line, so parallel additions don't conflict).
List<Component> buildFeatures() => [
      // Room first: painted behind the cats (priority -100), see lib/features/room/.
      RoomScene(),
      FishRain(),
      ScoreHud(),
      TitleBanner(),
    ];
