import '../../models/models.dart';
import 'time_of_day.dart';

/// Pisos de seguridad: los stats nunca llegan a cero y la Conexión nunca se
/// desploma. En este juego no hay muerte, ni hambre, ni castigos por ausencia.
const double pisoVivo = 12;

/// Piso mientras el jugador no estaba: mucho más alto, para que volver a la
/// casa nunca sea un mal trago.
const double pisoAusencia = 30;

/// Piso de la Conexión compartida.
const double pisoConexion = 25;

/// La energía de una acción tampoco puede dejar al gatito tirado en el piso.
const double pisoEnergiaAccion = 15;

/// Energía que recuperan mientras duermen de madrugada, por hora.
const double regenEnergiaMadrugada = 2.5;

/// Cuánto baja cada stat por hora (antes del multiplicador de la franja).
class DecayRates {
  const DecayRates({
    this.animo = 1.2,
    this.energia = 1.8,
    this.carino = 0.9,
    this.social = 1.6,
    this.conexion = 0.5,
  });

  /// Tasas suaves por defecto: una tarde fuera de casa no arruina nada.
  static const DecayRates standard = DecayRates();

  final double animo;
  final double energia;
  final double carino;
  final double social;
  final double conexion;

  /// Cambio por hora de un stat en una franja (puede ser positivo: de madrugada
  /// la energía sube).
  double deltaPorHora(StatKind kind, DayPhase fase) {
    if (kind == StatKind.energia && fase.esDescanso) {
      return regenEnergiaMadrugada;
    }
    final base = switch (kind) {
      StatKind.animo => animo,
      StatKind.energia => energia,
      StatKind.carino => carino,
      StatKind.social => social,
    };
    return -base * fase.multiplicador;
  }

  /// Cambio por hora de la Conexión (siempre baja, muy despacio).
  double deltaConexionPorHora(DayPhase fase) => -conexion * fase.multiplicador;
}

/// Deriva de un gatito: el estado nuevo y el cambio real ya aplicado (con el
/// piso respetado), para poder contarlo en el resumen "Mientras no estabas…".
class DerivaGatito {
  const DerivaGatito({required this.gatito, required this.cambios});

  final CharacterState gatito;
  final Map<StatKind, double> cambios;
}

/// Deriva de la relación.
class DerivaRelacion {
  const DerivaRelacion({required this.relacion, required this.cambioConexion});

  final RelationshipState relacion;
  final double cambioConexion;
}

/// Deriva de la partida completa (los dos gatitos + la Conexión).
class DerivaEstado {
  const DerivaEstado({
    required this.estado,
    required this.cambiosGatitos,
    required this.cambioConexion,
  });

  final TamagotchiState estado;

  /// id del gatito -> cambio real por stat.
  final Map<String, Map<StatKind, double>> cambiosGatitos;

  final double cambioConexion;
}

/// Diferencia real entre dos estados de un mismo gatito.
Map<StatKind, double> cambiosEntre(
  CharacterState antes,
  CharacterState despues,
) => <StatKind, double>{
  for (final kind in StatKind.values)
    kind: despues.stat(kind) - antes.stat(kind),
};

double _horas(Duration tiempo) =>
    tiempo.inMilliseconds / Duration.millisecondsPerHour;

/// Deriva de un gatito tras [tiempo] en la franja [fase].
DerivaGatito derivarGatito(
  CharacterState gatito,
  Duration tiempo,
  DayPhase fase, {
  DecayRates rates = DecayRates.standard,
  double piso = pisoVivo,
}) {
  final horas = _horas(tiempo);
  final deltas = <StatKind, double>{
    for (final kind in StatKind.values)
      kind: rates.deltaPorHora(kind, fase) * horas,
  };
  final nuevo = gatito.aplicar(deltas, piso: piso);
  return DerivaGatito(gatito: nuevo, cambios: cambiosEntre(gatito, nuevo));
}

/// Deriva de la Conexión tras [tiempo] en la franja [fase].
DerivaRelacion derivarRelacion(
  RelationshipState relacion,
  Duration tiempo,
  DayPhase fase, {
  DecayRates rates = DecayRates.standard,
  double piso = pisoConexion,
}) {
  final delta = rates.deltaConexionPorHora(fase) * _horas(tiempo);
  final nueva = relacion.conConexion(relacion.conexion + delta, piso: piso);
  return DerivaRelacion(
    relacion: nueva,
    cambioConexion: nueva.conexion - relacion.conexion,
  );
}

/// Deriva toda la partida (los dos gatitos y la Conexión) sin tocar otras cosas.
DerivaEstado derivarEstado(
  TamagotchiState estado,
  Duration tiempo,
  DayPhase fase, {
  DecayRates rates = DecayRates.standard,
  double pisoStats = pisoVivo,
  double pisoRelacion = pisoConexion,
}) {
  if (tiempo <= Duration.zero) {
    return DerivaEstado(
      estado: estado,
      cambiosGatitos: <String, Map<StatKind, double>>{
        for (final id in estado.gatitos.keys)
          id: <StatKind, double>{for (final kind in StatKind.values) kind: 0},
      },
      cambioConexion: 0,
    );
  }

  final gatitos = <String, CharacterState>{};
  final cambios = <String, Map<StatKind, double>>{};
  for (final entrada in estado.gatitos.entries) {
    final deriva = derivarGatito(
      entrada.value,
      tiempo,
      fase,
      rates: rates,
      piso: pisoStats,
    );
    gatitos[entrada.key] = deriva.gatito;
    cambios[entrada.key] = deriva.cambios;
  }

  final derivaRelacion = derivarRelacion(
    estado.relacion,
    tiempo,
    fase,
    rates: rates,
    piso: pisoRelacion,
  );

  return DerivaEstado(
    estado: estado.copyWith(
      gatitos: gatitos,
      relacion: derivaRelacion.relacion,
    ),
    cambiosGatitos: cambios,
    cambioConexion: derivaRelacion.cambioConexion,
  );
}
