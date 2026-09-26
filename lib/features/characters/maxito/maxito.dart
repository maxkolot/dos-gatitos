import 'package:flame/components.dart';

import 'maxito_bubble.dart';
import 'maxito_character.dart';
import 'maxito_state.dart';

export 'maxito_blink.dart';
export 'maxito_bubble.dart';
export 'maxito_character.dart';
export 'maxito_state.dart';

/// Maxito's corner of the flat: the animated character + his speech bubble.
///
/// Registered with one line in `features.dart`:
/// ```dart
/// ...buildMaxito(),
/// ```
///
/// Drive him through [MaxitoController.instance] (see maxito_state.dart).
List<Component> buildMaxito() => <Component>[
      MaxitoCharacter(),
      MaxitoBubble(),
    ];
