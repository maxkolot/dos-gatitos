import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import 'actions.dart';
import 'decay.dart';
import 'offline.dart';
import 'store.dart';
import 'time_of_day.dart';

/// El bucle del Tamagotchi, sin nada de dibujo ni de red.
///
/// Uso típico desde la UI:
/// ```dart
/// final loop = TamagotchiLoop();              // usa shared_preferences
/// await loop.cargar();                        // lee + aplica la ausencia
/// if (loop.hayInformeBienvenida) mostrar(loop.informeBienvenida!);
/// loop.activar(TamagotchiAction.darUnAbrazo); // el botón de la UI
/// loop.avanzar(Duration(milliseconds: 16));   // cada frame (deriva suave)
/// ```
class TamagotchiLoop extends ChangeNotifier {
  TamagotchiLoop({
    TamagotchiStore? store,
    DateTime Function()? reloj,
    DecayRates rates = DecayRates.standard,
    Duration intervaloGuardado = const Duration(seconds: 30),
  }) : _store = store ?? SharedPrefsTamagotchiStore(),
       _reloj = reloj ?? DateTime.now,
       _tasas = rates,
       _cadaCuantoGuardar = intervaloGuardado {
    _estado = TamagotchiState.nuevo(_reloj());
  }

  final TamagotchiStore _store;
  final DateTime Function() _reloj;
  final DecayRates _tasas;
  final Duration _cadaCuantoGuardar;

  late TamagotchiState _estado;
  Duration _pendienteDeGuardar = Duration.zero;
  bool _cargado = false;
  bool _guardando = false;
  bool _guardadoPendiente = false;
  Future<void>? _guardadoEnCurso;
  String? _error;
  OfflineReport? _informeBienvenida;

  /// La partida actual. Inmutable: cambia entera y avisa por [notifyListeners].
  TamagotchiState get estado => _estado;

  CharacterState get sebastian => _estado.sebastian;

  CharacterState get maxito => _estado.maxito;

  List<CharacterState> get gatitos => _estado.ambos;

  double get conexion => _estado.relacion.conexion;

  int get momentos => _estado.relacion.momentos;

  /// Días que llevan juntos (para el saludo).
  int get diasJuntos => _estado.diasJuntos(_reloj());

  /// Franja del día actual: Mañana / Tarde / Noche / Madrugada.
  DayPhase get fase => faseDe(_reloj());

  String get saludo => fase.saludo;

  /// Nombre visible del stat compartido ("Conexión").
  String get etiquetaConexion => RelationshipState.labelEs;

  /// true después de [cargar]: la UI puede decidir esperar antes de dibujar.
  bool get cargado => _cargado;

  /// Último error de guardado/lectura (no crítico, siempre se puede seguir).
  String? get error => _error;

  bool get guardando => _guardando;

  /// El resumen "Mientras no estabas…", si volvió después de un rato.
  OfflineReport? get informeBienvenida => _informeBienvenida;

  bool get hayInformeBienvenida => _informeBienvenida != null;

  /// Las seis acciones, en orden.
  List<TamagotchiAction> get acciones => TamagotchiAction.values;

  /// Definición (textos, icono, deltas) de una acción.
  ActionSpec spec(TamagotchiAction accion) => specDe(accion);

  /// Cuánto rendiría la acción ahora: 1.0 normal, menos si la repiten enseguida.
  /// La UI lo puede mostrar como "algo cansino" sin bloquear nunca el botón.
  double factorDe(TamagotchiAction accion) => factorDeRepeticion(
    _estado.ultimaVezDe(accion.name),
    _reloj(),
    specDe(accion),
  );

  /// Lee la partida guardada y aplica el tiempo que pasó sin jugador.
  /// Si no hay guardado (o está roto) empieza una partida nueva.
  Future<void> cargar({DateTime? ahora, bool aplicarAusencia = true}) async {
    final momento = ahora ?? _reloj();
    try {
      final guardado = await _store.leer();
      _estado = guardado ?? TamagotchiState.nuevo(momento);
      _error = null;
    } catch (e) {
      _estado = TamagotchiState.nuevo(momento);
      _error = 'No se pudo leer la partida guardada: $e';
    }
    _cargado = true;

    if (aplicarAusencia) {
      final resultado = progresarSinJugador(
        _estado,
        hasta: momento,
        rates: _tasas,
      );
      _estado = resultado.estado;
      _informeBienvenida = resultado.informe;
      if (resultado.informe != null) await guardar(forzar: true);
    }

    notifyListeners();
  }

  /// Activa una acción del jugador. Devuelve el detalle o `null` si algo falló.
  ActionResult? activar(
    TamagotchiAction accion, {
    String? conQuien,
    DateTime? ahora,
  }) {
    try {
      final resultado = activarAccion(
        _estado,
        accion,
        conQuien: conQuien,
        ahora: ahora ?? _reloj(),
      );
      _estado = resultado.estado;
      _error = null;
      unawaited(guardar(forzar: true));
      notifyListeners();
      return resultado.resultado;
    } catch (e) {
      _error = 'No se pudo hacer ${specDe(accion).labelEs}: $e';
      notifyListeners();
      return null;
    }
  }

  /// Deriva suave en vivo: llamalo con el `dt` del juego. Guarda cada tanto.
  void avanzar(Duration dt) {
    if (dt <= Duration.zero) return;
    final deriva = derivarEstado(
      _estado,
      dt,
      faseDe(_reloj()),
      rates: _tasas,
      pisoStats: pisoVivo,
      pisoRelacion: pisoConexion,
    );
    _estado = deriva.estado.copyWith(vistoEn: _reloj());
    _pendienteDeGuardar += dt;
    notifyListeners();
    if (_pendienteDeGuardar >= _cadaCuantoGuardar) {
      _pendienteDeGuardar = Duration.zero;
      unawaited(guardar());
    }
  }

  /// El jugador cerró el cartel de bienvenida.
  void reconocerBienvenida() {
    if (_informeBienvenida == null) return;
    _informeBienvenida = null;
    notifyListeners();
  }

  /// Guarda ya (por ejemplo cuando la app pasa a segundo plano).
  ///
  /// Si llega otra petición mientras el almacenamiento todavía está escribiendo,
  /// no se pierde: se agrupa y al terminar se vuelve a escribir el estado más
  /// reciente. Así una acción rápida nunca queda fuera del guardado por una
  /// escritura anterior todavía en curso.
  Future<void> guardar({bool forzar = false}) {
    if (!forzar && !_cargado) return Future<void>.value();

    _guardadoPendiente = true;
    final enCurso = _guardadoEnCurso;
    if (enCurso != null) return enCurso;

    final ciclo = _drenarGuardados();
    _guardadoEnCurso = ciclo;
    return ciclo;
  }

  Future<void> _drenarGuardados() async {
    _guardando = true;
    try {
      while (_guardadoPendiente) {
        _guardadoPendiente = false;
        final estadoAEscribir = _estado;
        try {
          await _store.escribir(estadoAEscribir);
          _error = null;
        } catch (e) {
          _error = 'No se pudo guardar la partida: $e';
          notifyListeners();
        }
      }
    } finally {
      _guardando = false;
      _guardadoEnCurso = null;
    }
  }

  /// Borra el guardado y arranca de cero (menú de opciones).
  Future<void> reiniciar({DateTime? ahora}) async {
    final momento = ahora ?? _reloj();
    try {
      await _store.borrar();
    } catch (_) {
      // Da igual: igualmente empezamos de cero en memoria.
    }
    _estado = TamagotchiState.nuevo(momento);
    _informeBienvenida = null;
    _pendienteDeGuardar = Duration.zero;
    _cargado = true;
    await guardar(forzar: true);
    notifyListeners();
  }

  @override
  String toString() => 'TamagotchiLoop($fase.labelEs · $_estado)';
}
