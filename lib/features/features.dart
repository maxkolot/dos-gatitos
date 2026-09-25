import 'package:flame/components.dart';

import 'fish_rain.dart';
import 'score_hud.dart';
import 'title_banner.dart';

/// Every feature is one Component in its own file in this folder.
/// Adding one = ONE import line + ONE list line (this file merges line by line, so parallel additions don't conflict).
List<Component> buildFeatures() => [
      FishRain(),
      ScoreHud(),
      TitleBanner(),
    ];
