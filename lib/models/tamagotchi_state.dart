import 'characters.dart';
import 'character_state.dart';
import 'model_utils.dart';
import 'relationship_state.dart';

/// La partida completa: los dos gatitos, la relación entre ellos y cuándo se los
/// vio por última vez. Es lo único que se guarda en el dispositivo.
class TamagotchiState {
  const TamagotchiState({
    required this.gatitos,
    required this.relacion,
    required this.creadoEn,
    required this.vistoEn,
    this.ultimasAcciones = const <String, DateTime>{},
    this.version = versionActual,
  });

  /// Versión del formato de guardado.
  static const int versionActual = 1;

  /// Partida nueva y acogedora: los dos contentos, recién mudados a Barcelona.
  factory TamagotchiState.nuevo(DateTime ahora) => TamagotchiState(
    gatitos: <String, CharacterState>{
      Characters.sebastian: CharacterState(
        id: Characters.sebastian,
        name: Characters.nombre(Characters.sebastian),
        animo: 72,
        energia: 78,
        carino: 66,
        social: 58,
      ),
      Characters.maxito: CharacterState(
        id: Characters.maxito,
        name: Characters.nombre(Characters.maxito),
        animo: 78,
        energia: 84,
        carino: 68,
        social: 70,
      ),
    },
    relacion: RelationshipState(desde: ahora),
    creadoEn: ahora,
    vistoEn: ahora,
  );

  final Map<String, CharacterState> gatitos;
  final RelationshipState relacion;

  /// Cuándo empezó la partida.
  final DateTime creadoEn;

  /// Última vez que el jugador estuvo presente.
  final DateTime vistoEn;

  /// Última vez que se usó cada acción (clave: `TamagotchiAction.name`).
  /// Sirve para que repetir lo mismo enseguida valga un poco menos, sin castigar.
  final Map<String, DateTime> ultimasAcciones;

  final int version;

  /// Gatito por id; si el id no existe, devuelve uno recién creado con ese id.
  CharacterState gatito(String id) =>
      gatitos[id] ?? CharacterState(id: id, name: Characters.nombre(id));

  CharacterState get sebastian => gatito(Characters.sebastian);

  CharacterState get maxito => gatito(Characters.maxito);

  /// Los dos, en orden canónico (para el HUD).
  List<CharacterState> get ambos => <CharacterState>[sebastian, maxito];

  DateTime? ultimaVezDe(String nombreAccion) => ultimasAcciones[nombreAccion];

  /// Días que llevan juntos (para el saludo de la UI).
  int diasJuntos(DateTime ahora) => relacion.diasJuntos(ahora);

  TamagotchiState conGatito(CharacterState gatito) => copyWith(
    gatitos: <String, CharacterState>{...gatitos, gatito.id: gatito},
  );

  TamagotchiState conGatitos(Map<String, CharacterState> nuevos) =>
      copyWith(gatitos: nuevos);

  TamagotchiState conUltimaVez(String nombreAccion, DateTime cuando) =>
      copyWith(
        ultimasAcciones: <String, DateTime>{
          ...ultimasAcciones,
          nombreAccion: cuando,
        },
      );

  TamagotchiState copyWith({
    Map<String, CharacterState>? gatitos,
    RelationshipState? relacion,
    DateTime? creadoEn,
    DateTime? vistoEn,
    Map<String, DateTime>? ultimasAcciones,
    int? version,
  }) => TamagotchiState(
    gatitos: gatitos ?? this.gatitos,
    relacion: relacion ?? this.relacion,
    creadoEn: creadoEn ?? this.creadoEn,
    vistoEn: vistoEn ?? this.vistoEn,
    ultimasAcciones: ultimasAcciones ?? this.ultimasAcciones,
    version: version ?? this.version,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'creadoEn': creadoEn.toIso8601String(),
    'vistoEn': vistoEn.toIso8601String(),
    'gatitos': <String, Object?>{
      for (final entrada in gatitos.entries)
        entrada.key: entrada.value.toJson(),
    },
    'relacion': relacion.toJson(),
    'ultimasAcciones': <String, Object?>{
      for (final entrada in ultimasAcciones.entries)
        entrada.key: entrada.value.toIso8601String(),
    },
  };

  /// Lee la partida del guardado. Devuelve `null` sólo si el JSON no tiene ni
  /// fecha de creación: todo lo demás se completa con valores sanos.
  static TamagotchiState? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;
    final creadoEn = fechaDeJson(crudo['creadoEn']);
    final vistoEn = fechaDeJson(crudo['vistoEn']);
    if (creadoEn == null) return null;

    final crudoGatitos = crudo['gatitos'];
    final gatitos = <String, CharacterState>{};
    for (final id in Characters.ids) {
      final crudoGatito = crudoGatitos is Map ? crudoGatitos[id] : null;
      gatitos[id] = crudoGatito is Map
          ? CharacterState.desdeJson(crudoGatito, idPorDefecto: id)
          : CharacterState(id: id, name: Characters.nombre(id));
    }

    final crudoRelacion = crudo['relacion'];
    final relacion = crudoRelacion is Map
        ? RelationshipState.desdeJson(crudoRelacion)
        : RelationshipState(desde: creadoEn);

    final ultimasAcciones = <String, DateTime>{};
    final crudoUltimas = crudo['ultimasAcciones'];
    if (crudoUltimas is Map) {
      for (final entrada in crudoUltimas.entries) {
        final clave = entrada.key;
        final cuando = fechaDeJson(entrada.value);
        if (clave is String && cuando != null) ultimasAcciones[clave] = cuando;
      }
    }

    return TamagotchiState(
      gatitos: gatitos,
      relacion: relacion,
      creadoEn: creadoEn,
      vistoEn: vistoEn ?? creadoEn,
      ultimasAcciones: ultimasAcciones,
      version: enteroDeJson(crudo['version'], versionActual),
    );
  }

  @override
  String toString() =>
      'TamagotchiState(${ambos.join(' · ')}, ${relacion.conexion.toStringAsFixed(1)} de '
      '${RelationshipState.labelEs})';
}
