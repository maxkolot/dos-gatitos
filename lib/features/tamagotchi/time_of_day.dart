/// Las cuatro franjas del día de la casa en Barcelona.
enum DayPhase { madrugada, manana, tarde, noche }

extension DayPhaseInfo on DayPhase {
  /// Nombre visible al jugador.
  String get labelEs => switch (this) {
    DayPhase.madrugada => 'Madrugada',
    DayPhase.manana => 'Mañana',
    DayPhase.tarde => 'Tarde',
    DayPhase.noche => 'Noche',
  };

  /// Saludo para el HUD / la entrada en escena.
  String get saludo => switch (this) {
    DayPhase.madrugada => 'Buena madrugada',
    DayPhase.manana => 'Buenos días',
    DayPhase.tarde => 'Buenas tardes',
    DayPhase.noche => 'Buenas noches',
  };

  /// Cuánto se desgastan los stats en esta franja (multiplica a las tasas).
  double get multiplicador => switch (this) {
    DayPhase.madrugada => 0.5,
    DayPhase.manana => 1,
    DayPhase.tarde => 1.05,
    DayPhase.noche => 1.15,
  };

  /// De madrugada duermen: la energía se recupera en vez de bajar.
  bool get esDescanso => this == DayPhase.madrugada;
}

/// Franja del día para una hora del reloj (0-23).
/// Madrugada 00-05, Mañana 06-11, Tarde 12-17, Noche 18-23.
DayPhase faseDeHora(int hora) {
  if (hora < 0) return DayPhase.madrugada;
  if (hora < 6) return DayPhase.madrugada;
  if (hora < 12) return DayPhase.manana;
  if (hora < 18) return DayPhase.tarde;
  return DayPhase.noche;
}

/// Franja del día de un momento concreto.
DayPhase faseDe(DateTime momento) => faseDeHora(momento.hour);
