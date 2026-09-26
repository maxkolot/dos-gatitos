import 'model_utils.dart';
import 'stats.dart';

/// Estado de un gatito: sus cuatro stats, siempre dentro de 0..100.
///
/// Es inmutable a propósito: cada cambio devuelve una copia nueva, así el motor
/// es fácil de testear y no hay efectos raros por referencias compartidas.
class CharacterState {
  const CharacterState({
    required this.id,
    required this.name,
    this.animo = 70,
    this.energia = 80,
    this.carino = 65,
    this.social = 60,
  });

  /// Piso absoluto: los stats nunca llegan a cero (acá nadie se hunde).
  static const double min = 0;

  /// Techo de todos los stats.
  static const double max = 100;

  /// Id estable ('sebastian' | 'maxito'): es la clave del guardado.
  final String id;

  /// Nombre visible del gatito.
  final String name;

  /// Ánimo.
  final double animo;

  /// Energía (el único stat que las acciones pueden gastar).
  final double energia;

  /// Cariño.
  final double carino;

  /// Social.
  final double social;

  double stat(StatKind kind) => switch (kind) {
    StatKind.animo => animo,
    StatKind.energia => energia,
    StatKind.carino => carino,
    StatKind.social => social,
  };

  /// Todos los stats juntos (para HUD y tests).
  Map<StatKind, double> get todos => <StatKind, double>{
    for (final kind in StatKind.values) kind: stat(kind),
  };

  /// Copia con [kind] en [valor], recortado a [piso]..[techo]. Un valor no
  /// finito se ignora (se queda el que ya estaba).
  CharacterState conStat(
    StatKind kind,
    double valor, {
    double piso = min,
    double techo = max,
  }) {
    final v = limitar(valor, piso, techo, porDefecto: stat(kind));
    return switch (kind) {
      StatKind.animo => copyWith(animo: v),
      StatKind.energia => copyWith(energia: v),
      StatKind.carino => copyWith(carino: v),
      StatKind.social => copyWith(social: v),
    };
  }

  /// Aplica un mapa de deltas (por ejemplo, una hora de deriva) con un piso
  /// común. Devuelve un gatito nuevo.
  CharacterState aplicar(
    Map<StatKind, double> deltas, {
    double piso = min,
    double techo = max,
  }) {
    var resultado = this;
    for (final entrada in deltas.entries) {
      resultado = resultado.conStat(
        entrada.key,
        resultado.stat(entrada.key) + entrada.value,
        piso: piso,
        techo: techo,
      );
    }
    return resultado;
  }

  /// El stat más bajo: la UI lo usa para decir qué mimo conviene.
  StatKind get statMasBajo {
    var peor = StatKind.values.first;
    for (final kind in StatKind.values) {
      if (stat(kind) < stat(peor)) peor = kind;
    }
    return peor;
  }

  /// true si algún stat está flojo (no es un castigo, es una pista).
  bool get necesitaMimo => todos.values.any((v) => v < 35);

  CharacterState copyWith({
    String? id,
    String? name,
    double? animo,
    double? energia,
    double? carino,
    double? social,
  }) => CharacterState(
    id: id ?? this.id,
    name: name ?? this.name,
    animo: valorFinito(animo ?? this.animo, this.animo),
    energia: valorFinito(energia ?? this.energia, this.energia),
    carino: valorFinito(carino ?? this.carino, this.carino),
    social: valorFinito(social ?? this.social, this.social),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'animo': animo,
    'energia': energia,
    'carino': carino,
    'social': social,
  };

  /// Lee un gatito del guardado. Nunca falla: lo que falta se completa con los
  /// valores iniciales.
  factory CharacterState.desdeJson(
    Map<Object?, Object?> json, {
    String? idPorDefecto,
  }) {
    final id = textoDeJson(json['id']) ?? idPorDefecto ?? 'gatito';
    return CharacterState(
      id: id,
      name: textoDeJson(json['name']) ?? id,
      animo: limitar(numeroDeJson(json['animo'], 70), min, max),
      energia: limitar(numeroDeJson(json['energia'], 80), min, max),
      carino: limitar(numeroDeJson(json['carino'], 65), min, max),
      social: limitar(numeroDeJson(json['social'], 60), min, max),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterState &&
      other.id == id &&
      other.name == name &&
      other.animo == animo &&
      other.energia == energia &&
      other.carino == carino &&
      other.social == social;

  @override
  int get hashCode => Object.hash(id, name, animo, energia, carino, social);

  @override
  String toString() =>
      'CharacterState($id: ánimo ${animo.toStringAsFixed(1)}, '
      'energía ${energia.toStringAsFixed(1)}, cariño ${carino.toStringAsFixed(1)}, '
      'social ${social.toStringAsFixed(1)})';
}
