import 'model_utils.dart';

/// Los cuatro stats propios de cada gatito.
///
/// El quinto (Conexión) es compartido y vive en `RelationshipState`.
enum StatKind { animo, energia, carino, social }

extension StatKindInfo on StatKind {
  /// Nombre visible al jugador (todo el juego está en español).
  String get labelEs => switch (this) {
    StatKind.animo => 'Ánimo',
    StatKind.energia => 'Energía',
    StatKind.carino => 'Cariño',
    StatKind.social => 'Social',
  };

  /// Ayuda para la UI: una línea sobre qué conviene hacer cuando está bajo.
  String get sugerenciaEs => switch (this) {
    StatKind.animo => 'Poné música: se les pasa el bajón.',
    StatKind.energia => 'Dejalos descansar un rato.',
    StatKind.carino => 'Un abrazo los deja nuevos.',
    StatKind.social => 'Hablen un rato, o sirvan una copa.',
  };

  /// Los stats "de vínculo" no se gastan: las acciones nunca los bajan.
  bool get esGasto => this == StatKind.energia;
}

/// Busca un [StatKind] por su nombre (clave del guardado y de las acciones).
StatKind? statKindPorNombre(String? nombre) {
  if (nombre == null) return null;
  for (final kind in StatKind.values) {
    if (kind.name == nombre) return kind;
  }
  return null;
}

/// Recorta [valor] a [min]..[max] después de sanearlo.
double limitar(double valor, double min, double max, {double porDefecto = 0}) =>
    valorFinito(valor, porDefecto).clamp(min, max);
