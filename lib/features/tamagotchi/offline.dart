import '../../models/models.dart';
import 'decay.dart';
import 'time_of_day.dart';

/// Un momentito que pasó en la casa mientras el jugador no estaba.
/// Los cambios son suaves y positivos: acá nadie se castiga por ausentarse.
class MomentoAusencia {
  const MomentoAusencia({
    required this.tituloEs,
    required this.lineaEs,
    required this.deltas,
    this.conexion = 1,
  });

  final String tituloEs;
  final String lineaEs;
  final Map<StatKind, double> deltas;
  final double conexion;
}

/// Cosas lindas que pueden haber pasado sin el jugador. Lista fija y
/// determinista: el resumen es reproducible (y fácil de testear).
const List<MomentoAusencia> catalogoMomentos = <MomentoAusencia>[
  MomentoAusencia(
    tituloEs: 'Música en la cocina',
    lineaEs: 'Pusieron un disco y bailaron mal a propósito.',
    deltas: <StatKind, double>{StatKind.animo: 3, StatKind.social: 2},
  ),
  MomentoAusencia(
    tituloEs: 'Siesta en el sofá',
    lineaEs: 'Se quedaron dormidos uno encima del otro mirando la ciudad.',
    deltas: <StatKind, double>{StatKind.energia: 4, StatKind.carino: 2},
  ),
  MomentoAusencia(
    tituloEs: 'Copa de vino',
    lineaEs: 'Abrieron una botella y brindaron por vos, sin vos.',
    deltas: <StatKind, double>{StatKind.animo: 3, StatKind.social: 2},
  ),
  MomentoAusencia(
    tituloEs: 'Charla de madrugada',
    lineaEs: 'Hablaron de mudarse a un piso con balcón. Otra vez.',
    deltas: <StatKind, double>{StatKind.social: 3, StatKind.carino: 2},
    conexion: 2,
  ),
  MomentoAusencia(
    tituloEs: 'Gato en el teclado',
    lineaEs: 'Uno intentó trabajar y el otro se sentó arriba del teclado.',
    deltas: <StatKind, double>{StatKind.animo: 3, StatKind.social: 1},
  ),
  MomentoAusencia(
    tituloEs: 'Vuelta por Gràcia',
    lineaEs: 'Caminaron hasta la plaza y volvieron con pan y tomates.',
    deltas: <StatKind, double>{StatKind.energia: 2, StatKind.animo: 3},
  ),
  MomentoAusencia(
    tituloEs: 'Película malísima',
    lineaEs: 'Pusieron una película mala y la comentaron entera.',
    deltas: <StatKind, double>{StatKind.animo: 3, StatKind.social: 2},
  ),
  MomentoAusencia(
    tituloEs: 'Mate y silencio',
    lineaEs: 'Uno cebó mate y el otro dijo "spasibo" sin levantar la vista.',
    deltas: <StatKind, double>{StatKind.carino: 3, StatKind.animo: 2},
    conexion: 2,
  ),
];

/// Texto humano de una duración: "20 min", "3 h 20 min", "2 días 4 h".
String textoDuracion(Duration duracion) {
  final total = duracion.isNegative ? Duration.zero : duracion;
  if (total.inMinutes < 1) return 'un momento';
  if (total.inMinutes < 60) return '${total.inMinutes} min';
  if (total.inHours < 24) {
    final minutos = total.inMinutes % 60;
    return minutos == 0
        ? '${total.inHours} h'
        : '${total.inHours} h $minutos min';
  }
  final dias = total.inDays;
  final horas = total.inHours % 24;
  final etiquetaDias = dias == 1 ? '1 día' : '$dias días';
  return horas == 0 ? etiquetaDias : '$etiquetaDias $horas h';
}

/// Lo que pasó mientras el jugador no estaba. Nunca hay malas noticias: como
/// mucho, los stats se quedaron flojos y hay que dar un abrazo.
class OfflineReport {
  const OfflineReport({
    required this.desde,
    required this.hasta,
    required this.fase,
    required this.cambios,
    required this.cambioConexion,
    required this.momentos,
    required this.llegoAlPiso,
  });

  final DateTime desde;
  final DateTime hasta;
  final DayPhase fase;

  /// id del gatito -> cambio real por stat.
  final Map<String, Map<StatKind, double>> cambios;

  final double cambioConexion;
  final List<MomentoAusencia> momentos;

  /// true si algún stat se apoyó en el piso de ausencia (nunca es drama).
  final bool llegoAlPiso;

  Duration get ausencia => hasta.difference(desde);

  /// Título fijo del cartel de bienvenida.
  String get titulo => 'Mientras no estabas…';

  /// "Estuviste fuera 3 h 20 min · Tarde".
  String get resumenCorto =>
      'Estuviste fuera ${textoDuracion(ausencia)} · ${fase.labelEs}';

  /// Cierre del resumen: tranquilo, cálido y sin reproches.
  String get cierre => llegoAlPiso
      ? 'Todo tranquilo: la casa sigue en pie y nadie se enojó. Algún ánimo quedó un poco bajo, nada que un abrazo no arregle.'
      : 'Todo tranquilo: te esperaron sin dramas y siguen con ganas de verte.';

  /// Las líneas del resumen, listas para pintar en el cartel.
  List<String> get lineas => <String>[
    if (momentos.isEmpty)
      'La casa quedó en silencio, tranquila.'
    else
      ...momentos.map((m) => m.lineaEs),
    cierre,
  ];

  @override
  String toString() =>
      'OfflineReport($resumenCorto, ${momentos.length} momentos)';
}

/// Avanza la partida como si el jugador hubiera estado ausente hasta [hasta].
///
/// - Si la ausencia es menor a [ausenciaMinima], no pasa nada (ni resumen).
/// - Los stats bajan suave y nunca por debajo de [pisoAusencia].
/// - La Conexión nunca baja de [pisoConexion] y los momentos la suben un poco.
/// - De madrugada incluso recuperan energía.
({TamagotchiState estado, OfflineReport? informe}) progresarSinJugador(
  TamagotchiState estado, {
  required DateTime hasta,
  Duration ausenciaMinima = const Duration(minutes: 5),
  Duration ritmoMomentos = const Duration(minutes: 45),
  int maxMomentos = 8,
  DecayRates rates = DecayRates.standard,
}) {
  var ausencia = hasta.difference(estado.vistoEn);
  if (ausencia.isNegative) ausencia = Duration.zero;

  if (ausencia < ausenciaMinima) {
    return (estado: estado.copyWith(vistoEn: hasta), informe: null);
  }

  final fase = faseDe(hasta);
  final antes = <String, CharacterState>{
    for (final id in estado.gatitos.keys) id: estado.gatito(id),
  };
  final antesConexion = estado.relacion.conexion;

  final deriva = derivarEstado(
    estado,
    ausencia,
    fase,
    rates: rates,
    pisoStats: pisoAusencia,
    pisoRelacion: pisoConexion,
  );
  var nuevo = deriva.estado;

  // ¿Algún stat se apoyó en el piso durante la ausencia? Se mira antes de los
  // momentos (que después suben un poquito), y sólo cambia el texto del cierre.
  final llegoAlPiso = deriva.estado.gatitos.values.any(
    (g) => StatKind.values.any((k) => (g.stat(k) - pisoAusencia).abs() < 0.001),
  );

  // Momentos vividos: uno cada [ritmoMomentos], como mínimo uno, con tope.
  final ritmo = ritmoMomentos.inMinutes <= 0 ? 1 : ritmoMomentos.inMinutes;
  final cuantos = (ausencia.inMinutes ~/ ritmo).clamp(1, maxMomentos).toInt();
  final arranque =
      (fase.index * 3 + ausencia.inHours) % catalogoMomentos.length;
  final momentos = <MomentoAusencia>[
    for (var i = 0; i < cuantos; i++)
      catalogoMomentos[(arranque + i) % catalogoMomentos.length],
  ];

  var conexionExtra = 0.0;
  for (final momento in momentos) {
    conexionExtra += momento.conexion;
    nuevo = nuevo.conGatitos(<String, CharacterState>{
      for (final entrada in nuevo.gatitos.entries)
        entrada.key: entrada.value.aplicar(momento.deltas, piso: pisoAusencia),
    });
  }

  nuevo = nuevo.copyWith(
    relacion: nuevo.relacion
        .conConexion(nuevo.relacion.conexion + conexionExtra)
        .conMomentos(momentos.length),
    vistoEn: hasta,
  );

  final cambios = <String, Map<StatKind, double>>{
    for (final entrada in nuevo.gatitos.entries)
      entrada.key: cambiosEntre(
        antes[entrada.key] ?? entrada.value,
        entrada.value,
      ),
  };

  return (
    estado: nuevo,
    informe: OfflineReport(
      desde: estado.vistoEn,
      hasta: hasta,
      fase: fase,
      cambios: cambios,
      cambioConexion: nuevo.relacion.conexion - antesConexion,
      momentos: momentos,
      llegoAlPiso: llegoAlPiso,
    ),
  );
}
