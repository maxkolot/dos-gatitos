import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

/// Dónde vive la partida entre sesiones.
abstract class TamagotchiStore {
  /// Lee la partida guardada; `null` si no hay nada (o si el guardado está roto).
  Future<TamagotchiState?> leer();

  Future<void> escribir(TamagotchiState estado);

  Future<void> borrar();
}

/// Guardado real en el dispositivo (shared_preferences: web, iOS, Android,
/// escritorio). Nada de API keys ni de red: sólo los stats.
class SharedPrefsTamagotchiStore implements TamagotchiStore {
  /// Clave con versión: si cambia el formato, se sube el sufijo.
  static const String clave = 'dos_gatitos.tamagotchi.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<TamagotchiState?> leer() async {
    try {
      final crudo = (await _prefs).getString(clave);
      if (crudo == null || crudo.isEmpty) return null;
      return TamagotchiState.desdeJson(jsonDecode(crudo));
    } catch (_) {
      // Guardado viejo, cortado o con basura: mejor empezar de cero que romper.
      return null;
    }
  }

  @override
  Future<void> escribir(TamagotchiState estado) async {
    final prefs = await _prefs;
    await prefs.setString(clave, jsonEncode(estado.toJson()));
  }

  @override
  Future<void> borrar() async {
    await (await _prefs).remove(clave);
  }
}

/// Guardado en memoria: tests, demos y modo incógnito. No toca el plugin.
class MemoriaTamagotchiStore implements TamagotchiStore {
  MemoriaTamagotchiStore({String? crudoInicial}) : _crudo = crudoInicial;

  String? _crudo;

  /// Cuántas veces se escribió (para los tests).
  int escrituras = 0;

  /// Cuántas veces se leyó (para los tests).
  int lecturas = 0;

  /// El último JSON guardado, tal cual.
  String? get crudo => _crudo;

  @override
  Future<TamagotchiState?> leer() async {
    lecturas++;
    final crudo = _crudo;
    if (crudo == null || crudo.isEmpty) return null;
    try {
      return TamagotchiState.desdeJson(jsonDecode(crudo));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> escribir(TamagotchiState estado) async {
    escrituras++;
    _crudo = jsonEncode(estado.toJson());
  }

  @override
  Future<void> borrar() async {
    _crudo = null;
  }
}
