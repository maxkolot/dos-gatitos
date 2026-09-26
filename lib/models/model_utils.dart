// Helpers chiquitos para leer el guardado sin reventar aunque venga viejo,
// cortado o con basura. Todo lo que entra por acá sale saneado.

/// Devuelve [valor] si es un número finito; si no, [porDefecto].
/// Evita NaN/Infinity en los stats (un NaN rompería todos los clamps).
double valorFinito(double valor, double porDefecto) =>
    valor.isFinite ? valor : porDefecto;

/// Lee un double del JSON: números ok, cualquier otra cosa -> [porDefecto].
double numeroDeJson(Object? valor, double porDefecto) =>
    valor is num ? valor.toDouble() : porDefecto;

/// Lee un int del JSON.
int enteroDeJson(Object? valor, int porDefecto) =>
    valor is num ? valor.toInt() : porDefecto;

/// Lee una fecha ISO-8601 del JSON.
DateTime? fechaDeJson(Object? valor) =>
    valor is String ? DateTime.tryParse(valor) : null;

/// Lee un texto no vacío del JSON.
String? textoDeJson(Object? valor) =>
    valor is String && valor.isNotEmpty ? valor : null;
