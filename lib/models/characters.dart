// Los dos protagonistas de la casa. Los ids son estables: van al JSON de
// guardado, así que no se cambian.

/// Sebastián (argentino, rioplatense, tranquilo e irónico) y Maxito (ruso,
/// pelirrojo, juguetón). Son pareja y viven juntos en Barcelona.
abstract final class Characters {
  static const String sebastian = 'sebastian';
  static const String maxito = 'maxito';

  /// Orden canónico para la UI.
  static const List<String> ids = <String>[sebastian, maxito];

  static const Map<String, String> nombres = <String, String>{
    sebastian: 'Sebastián',
    maxito: 'Maxito',
  };

  /// Nombre visible; si el id es desconocido, devuelve el id tal cual.
  static String nombre(String id) => nombres[id] ?? id;

  static bool esValido(String id) => nombres.containsKey(id);

  /// El otro gatito de la casa (para abrazos, charlas y preguntas).
  static String parejaDe(String id) => id == sebastian ? maxito : sebastian;
}
