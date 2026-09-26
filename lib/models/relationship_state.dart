import 'model_utils.dart';
import 'stats.dart';

/// Lo que comparten Sebastián y Maxito: la Conexión (stat compartido, no de uno
/// solo) y los momentos que ya vivieron juntos.
class RelationshipState {
  const RelationshipState({this.conexion = 50, this.momentos = 0, this.desde});

  /// Nombre visible del stat compartido.
  static const String labelEs = 'Conexión';

  static const double min = 0;
  static const double max = 100;

  /// La Conexión nunca se desploma: es un vínculo, no un medidor de castigo.
  static const double pisoDescanso = 25;

  final double conexion;

  /// Cuántas veces hicieron algo juntos (una por acción del jugador).
  final int momentos;

  /// Cuándo empezó la partida (para "días juntos").
  final DateTime? desde;

  /// Días completos desde que empezaron; 0 si todavía no hay fecha.
  int diasJuntos(DateTime ahora) {
    final inicio = desde;
    if (inicio == null) return 0;
    final dias = ahora.difference(inicio).inDays;
    return dias < 0 ? 0 : dias;
  }

  /// Copia con la conexión cambiada y recortada a [piso]..[max].
  RelationshipState conConexion(double valor, {double piso = min}) =>
      copyWith(conexion: limitar(valor, piso, max, porDefecto: conexion));

  /// Suma [cuantos] momentos (nunca negativos).
  RelationshipState conMomentos(int cuantos) {
    final total = momentos + cuantos;
    return copyWith(momentos: total < 0 ? 0 : total);
  }

  RelationshipState copyWith({
    double? conexion,
    int? momentos,
    DateTime? desde,
  }) => RelationshipState(
    conexion: limitar(
      conexion ?? this.conexion,
      min,
      max,
      porDefecto: this.conexion,
    ),
    momentos: momentos ?? this.momentos,
    desde: desde ?? this.desde,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'conexion': conexion,
    'momentos': momentos,
    'desde': desde?.toIso8601String(),
  };

  factory RelationshipState.desdeJson(Map<Object?, Object?> json) =>
      RelationshipState(
        conexion: limitar(numeroDeJson(json['conexion'], 50), min, max),
        momentos: enteroDeJson(json['momentos'], 0),
        desde: fechaDeJson(json['desde']),
      );

  @override
  bool operator ==(Object other) =>
      other is RelationshipState &&
      other.conexion == conexion &&
      other.momentos == momentos &&
      other.desde == desde;

  @override
  int get hashCode => Object.hash(conexion, momentos, desde);

  @override
  String toString() =>
      'RelationshipState($labelEs ${conexion.toStringAsFixed(1)}, momentos $momentos)';
}
