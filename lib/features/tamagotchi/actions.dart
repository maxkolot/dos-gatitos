import '../../models/models.dart';
import 'decay.dart';

/// Las cosas lindas que el jugador puede hacer con sus gatitos.
enum TamagotchiAction {
  ponerMusica,
  servirVino,
  hablar,
  darUnAbrazo,
  jugar,
  cenar,
  preguntar,
}

/// A quién le llega la acción.
enum ActionTarget {
  /// A los dos por igual (música, vino, jugar, abrazo).
  ambos,

  /// A uno en particular: el jugador elige con `conQuien` (hablar, preguntar).
  enfocada,
}

/// Definición de una acción: texto en español para la UI y números para el motor.
class ActionSpec {
  const ActionSpec({
    required this.labelEs,
    required this.descripcionEs,
    required this.icono,
    required this.deltas,
    this.conexion = 0,
    this.target = ActionTarget.ambos,
    this.focoCompleto = 1,
    this.resto = 0.6,
    this.ventanaRepeticion = const Duration(minutes: 30),
    this.factorRepeticion = 0.5,
  });

  /// Texto del botón, en español.
  final String labelEs;

  /// Una línea de sabor (tooltip / subtítulo).
  final String descripcionEs;

  /// Nombre de icono de Material; la UI lo convierte a `IconData`.
  final String icono;

  /// Cambios base por gatito. Sólo la Energía puede ser negativa.
  final Map<StatKind, double> deltas;

  /// Cuánta Conexión compartida suma.
  final double conexion;

  final ActionTarget target;

  /// Peso para el gatito elegido (sólo en acciones [ActionTarget.enfocada]).
  final double focoCompleto;

  /// Peso para el otro gatito, que igual participa de la escena.
  final double resto;

  /// Repetir la misma acción dentro de esta ventana vale un poco menos: nunca
  /// menos de [factorRepeticion]. No es un castigo, sólo evita el "farmeo".
  final Duration ventanaRepeticion;

  final double factorRepeticion;

  /// El precio más alto de energía de esta acción (para que la UI avise).
  double get gastoMaximoEnergia => deltas[StatKind.energia] ?? 0;
}

/// Catálogo de acciones. Los números son deliberadamente suaves: subir mucho
/// cuesta poco y bajar nunca duele.
const Map<TamagotchiAction, ActionSpec> catalogoAcciones =
    <TamagotchiAction, ActionSpec>{
      TamagotchiAction.ponerMusica: ActionSpec(
        labelEs: 'Poner música',
        descripcionEs: 'Un disco en la cocina: siempre termina en baile malo.',
        icono: 'music_note',
        deltas: <StatKind, double>{
          StatKind.animo: 8,
          StatKind.social: 6,
          StatKind.energia: -4,
        },
        conexion: 2,
      ),
      TamagotchiAction.servirVino: ActionSpec(
        labelEs: 'Servir vino',
        descripcionEs: 'Una copa de garnacha y la charla se pone mejor.',
        icono: 'wine_bar',
        deltas: <StatKind, double>{
          StatKind.animo: 7,
          StatKind.social: 7,
          StatKind.carino: 4,
          StatKind.energia: -3,
        },
        conexion: 3,
      ),
      TamagotchiAction.hablar: ActionSpec(
        labelEs: 'Hablar',
        descripcionEs: 'Elegí con quién y charlen un rato.',
        icono: 'chat_bubble',
        deltas: <StatKind, double>{StatKind.social: 9, StatKind.animo: 4},
        conexion: 4,
        target: ActionTarget.enfocada,
        resto: 0.6,
      ),
      TamagotchiAction.darUnAbrazo: ActionSpec(
        labelEs: 'Dar un abrazo',
        descripcionEs: 'Abrazo largo, de esos que arreglan la tarde.',
        icono: 'favorite',
        deltas: <StatKind, double>{
          StatKind.carino: 10,
          StatKind.animo: 7,
          StatKind.social: 4,
        },
        conexion: 6,
      ),
      TamagotchiAction.jugar: ActionSpec(
        labelEs: 'Jugar',
        descripcionEs: 'Perseguirse por el pasillo hasta cansarse (poco).',
        icono: 'sports_esports',
        deltas: <StatKind, double>{
          StatKind.animo: 9,
          StatKind.social: 7,
          StatKind.energia: -6,
        },
        conexion: 3,
      ),
      TamagotchiAction.cenar: ActionSpec(
        labelEs: 'Cenar milanesas',
        descripcionEs: 'Sebas cocina milanesas a la napolitana y comen juntos en el piso.',
        icono: 'restaurant',
        deltas: <StatKind, double>{
          StatKind.energia: 14,
          StatKind.animo: 7,
          StatKind.carino: 5,
          StatKind.social: 4,
        },
        conexion: 4,
      ),
      TamagotchiAction.preguntar: ActionSpec(
        labelEs: 'Preguntar',
        descripcionEs:
            'Preguntale lo que quieras: él contesta con sus palabras.',
        icono: 'help_outline',
        deltas: <StatKind, double>{StatKind.social: 6, StatKind.animo: 2},
        conexion: 2,
        target: ActionTarget.enfocada,
        resto: 0.5,
      ),
    };

/// Definición de una acción del catálogo.
ActionSpec specDe(TamagotchiAction accion) => catalogoAcciones[accion]!;

/// Busca una acción por su nombre (clave que va al guardado).
TamagotchiAction? accionPorNombre(String? nombre) {
  if (nombre == null) return null;
  for (final accion in TamagotchiAction.values) {
    if (accion.name == nombre) return accion;
  }
  return null;
}

/// Cuánto rinde repetir [accion] ahora mismo: 1.0 la primera vez y sube en
/// línea recta desde [ActionSpec.factorRepeticion] hasta 1.0 a lo largo de
/// [ActionSpec.ventanaRepeticion].
double factorDeRepeticion(
  DateTime? ultimaVez,
  DateTime ahora,
  ActionSpec spec,
) {
  if (ultimaVez == null) return 1;
  final desde = ahora.difference(ultimaVez);
  if (desde.isNegative) return 1; // reloj raro: no penalizamos a nadie
  final ventana = spec.ventanaRepeticion.inMilliseconds;
  if (ventana <= 0 || desde.inMilliseconds >= ventana) return 1;
  final avance = desde.inMilliseconds / ventana;
  return spec.factorRepeticion + (1 - spec.factorRepeticion) * avance;
}

/// Resultado de activar una acción: lo que cambió de verdad, listo para la UI.
class ActionResult {
  const ActionResult({
    required this.accion,
    required this.labelEs,
    required this.cambios,
    required this.cambioConexion,
    required this.cuando,
    this.conQuien,
    this.factor = 1,
  });

  final TamagotchiAction accion;
  final String labelEs;

  /// id del gatito -> cambio real por stat (ya recortado a los pisos).
  final Map<String, Map<StatKind, double>> cambios;

  final double cambioConexion;
  final DateTime cuando;

  /// El gatito elegido, si la acción era [ActionTarget.enfocada].
  final String? conQuien;

  /// 1.0 normalmente; menos si repitieron la acción enseguida.
  final double factor;

  bool get reducido => factor < 0.999;

  bool get huboCambio =>
      cambioConexion.abs() > 0.001 ||
      cambios.values.any(
        (porStat) => porStat.values.any((v) => v.abs() > 0.001),
      );

  /// Aviso suave para mostrar bajo el botón (nunca un reproche).
  String? get nota =>
      reducido ? 'Recién lo hicieron, así que cuenta un poco menos.' : null;

  @override
  String toString() =>
      'ActionResult($labelEs${conQuien == null ? '' : ' con $conQuien'}, '
      'conexión ${cambioConexion >= 0 ? '+' : ''}${cambioConexion.toStringAsFixed(1)})';
}

String _resolverFoco(TamagotchiState estado, String? conQuien) {
  if (conQuien != null && estado.gatitos.containsKey(conQuien)) return conQuien;
  if (estado.gatitos.isEmpty) return Characters.sebastian;
  return estado.gatitos.keys.first;
}

/// Activa una acción: devuelve la partida nueva y el detalle del cambio.
///
/// - Nunca baja Ánimo, Cariño, Social ni Conexión (sólo la Energía se gasta).
/// - Respeta los pisos ([pisoEnergiaAccion], `CharacterState.min`, `max`).
/// - Repetir la misma acción enseguida rinde menos, pero nunca cero.
({TamagotchiState estado, ActionResult resultado}) activarAccion(
  TamagotchiState estado,
  TamagotchiAction accion, {
  String? conQuien,
  DateTime? ahora,
}) {
  final momento = ahora ?? DateTime.now();
  final spec = specDe(accion);
  final factor = factorDeRepeticion(
    estado.ultimaVezDe(accion.name),
    momento,
    spec,
  );
  final foco = spec.target == ActionTarget.enfocada
      ? _resolverFoco(estado, conQuien)
      : null;

  var nuevo = estado;
  final cambios = <String, Map<StatKind, double>>{};

  for (final id in estado.gatitos.keys) {
    final antes = estado.gatito(id);
    final peso = foco == null
        ? 1.0
        : (id == foco ? spec.focoCompleto : spec.resto);
    var despues = antes;
    for (final entrada in spec.deltas.entries) {
      final piso = entrada.key.esGasto ? pisoEnergiaAccion : CharacterState.min;
      despues = despues.conStat(
        entrada.key,
        despues.stat(entrada.key) + entrada.value * factor * peso,
        piso: piso,
      );
    }
    nuevo = nuevo.conGatito(despues);
    cambios[id] = cambiosEntre(antes, despues);
  }

  final relacion = nuevo.relacion
      .conConexion(nuevo.relacion.conexion + spec.conexion * factor)
      .conMomentos(1);

  nuevo = nuevo
      .copyWith(relacion: relacion, vistoEn: momento)
      .conUltimaVez(accion.name, momento);

  return (
    estado: nuevo,
    resultado: ActionResult(
      accion: accion,
      labelEs: spec.labelEs,
      cambios: cambios,
      cambioConexion: nuevo.relacion.conexion - estado.relacion.conexion,
      cuando: momento,
      conQuien: foco,
      factor: factor,
    ),
  );
}
