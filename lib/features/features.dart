import 'package:flame/components.dart';

import 'characters/maxito/maxito.dart';
import 'characters/sebastian/sebastian_character.dart';
import 'room/room_scene.dart';

/// Active components of Dos Gatitos: the Barcelona flat behind, Sebastián and
/// Maxito standing on its floor with their names above them.
/// Adding a feature = ONE import line + ONE list line (this file merges line by line).
List<Component> buildFeatures() => [
      RoomScene(),
      SebastianCharacter(),
      ...buildMaxito(),
    ];
