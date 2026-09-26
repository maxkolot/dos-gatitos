import 'dart:async';

import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final arranque = DateTime(2026, 5, 1, 20);
  late DateTime ahora;

  DateTime reloj() => ahora;

  setUp(() => ahora = arranque);

  test('arranca una partida nueva cuando no hay nada guardado', () async {
    final loop = TamagotchiLoop(store: MemoriaTamagotchiStore(), reloj: reloj);

    await loop.cargar();

    expect(loop.cargado, isTrue);
    expect(loop.error, isNull);
    expect(loop.hayInformeBienvenida, isFalse);
    expect(loop.sebastian.name, 'Sebastián');
    expect(loop.maxito.name, 'Maxito');
    expect(loop.gatitos.length, 2);
    expect(loop.fase, DayPhase.noche);
    expect(loop.saludo, 'Buenas noches');
    expect(loop.etiquetaConexion, 'Conexión');
    expect(loop.conexion, 50);
    expect(loop.momentos, 0);
    expect(loop.diasJuntos, 0);

    loop.dispose();
  });

  test('activar una acción mueve el estado y lo persiste', () async {
    final store = MemoriaTamagotchiStore();
    final loop = TamagotchiLoop(store: store, reloj: reloj);
    await loop.cargar();

    final resultado = loop.activar(TamagotchiAction.servirVino);

    expect(resultado, isNotNull);
    expect(resultado!.labelEs, 'Servir vino');
    expect(loop.sebastian.animo, closeTo(79, 1e-6));
    expect(loop.conexion, closeTo(53, 1e-6));
    expect(loop.momentos, 1);

    await pumpEventQueue();
    expect(store.escrituras, greaterThanOrEqualTo(1));

    loop.dispose();
  });

  test('cada acción avisa a la UI (ChangeNotifier)', () async {
    final loop = TamagotchiLoop(store: MemoriaTamagotchiStore(), reloj: reloj);
    await loop.cargar();

    var avisos = 0;
    loop.addListener(() => avisos++);

    loop.activar(TamagotchiAction.jugar);
    loop.avanzar(const Duration(minutes: 1));

    expect(avisos, greaterThanOrEqualTo(2));

    loop.dispose();
  });

  test('avanzar deriva suave y guarda cada tanto', () async {
    final store = MemoriaTamagotchiStore();
    final loop = TamagotchiLoop(
      store: store,
      reloj: reloj,
      intervaloGuardado: const Duration(seconds: 10),
    );
    await loop.cargar();
    final animoAntes = loop.sebastian.animo;

    loop.avanzar(const Duration(seconds: 5));
    expect(loop.sebastian.animo, lessThan(animoAntes));
    expect(store.escrituras, 0);

    loop.avanzar(const Duration(seconds: 10));
    await pumpEventQueue();
    expect(store.escrituras, greaterThanOrEqualTo(1));
    expect(loop.estado.vistoEn, ahora);

    loop.dispose();
  });

  test('avanzar con dt cero o negativo no hace nada', () async {
    final loop = TamagotchiLoop(store: MemoriaTamagotchiStore(), reloj: reloj);
    await loop.cargar();
    final estadoAntes = loop.estado;

    loop.avanzar(Duration.zero);
    loop.avanzar(const Duration(seconds: -5));

    expect(loop.estado, estadoAntes);

    loop.dispose();
  });

  test('volver después de tres horas muestra "Mientras no estabas…"', () async {
    final store = MemoriaTamagotchiStore();
    final primero = TamagotchiLoop(store: store, reloj: reloj);
    await primero.cargar();
    await primero.guardar(forzar: true);
    primero.dispose();

    ahora = arranque.add(const Duration(hours: 3));
    final segundo = TamagotchiLoop(store: store, reloj: reloj);
    await segundo.cargar();

    expect(segundo.hayInformeBienvenida, isTrue);
    final informe = segundo.informeBienvenida!;
    expect(informe.titulo, 'Mientras no estabas…');
    expect(informe.lineas, isNotEmpty);
    expect(informe.momentos, isNotEmpty);
    for (final gatito in segundo.gatitos) {
      for (final kind in StatKind.values) {
        expect(gatito.stat(kind), greaterThanOrEqualTo(pisoAusencia - 1e-9));
      }
    }

    segundo.reconocerBienvenida();
    expect(segundo.hayInformeBienvenida, isFalse);

    segundo.dispose();
  });

  test('la partida sobrevive a cerrar y abrir la app', () async {
    final store = MemoriaTamagotchiStore();
    final primero = TamagotchiLoop(store: store, reloj: reloj);
    await primero.cargar();
    primero.activar(TamagotchiAction.jugar);
    primero.activar(TamagotchiAction.ponerMusica);
    await pumpEventQueue();
    await primero.guardar(forzar: true);
    final momentos = primero.momentos;
    final conexion = primero.conexion;
    primero.dispose();

    final segundo = TamagotchiLoop(store: store, reloj: reloj);
    await segundo.cargar();

    expect(segundo.momentos, momentos);
    expect(segundo.conexion, closeTo(conexion, 1e-9));
    expect(segundo.hayInformeBienvenida, isFalse);

    segundo.dispose();
  });

  test('factorDe refleja el cansancio de repetir y nunca bloquea', () async {
    final loop = TamagotchiLoop(store: MemoriaTamagotchiStore(), reloj: reloj);
    await loop.cargar();

    expect(loop.acciones.length, 7);
    expect(
      loop.acciones.map((a) => loop.spec(a).labelEs),
      contains('Dar un abrazo'),
    );
    expect(loop.factorDe(TamagotchiAction.ponerMusica), 1);

    loop.activar(TamagotchiAction.ponerMusica);
    expect(loop.factorDe(TamagotchiAction.ponerMusica), closeTo(0.5, 1e-9));

    ahora = ahora.add(const Duration(minutes: 30));
    expect(loop.factorDe(TamagotchiAction.ponerMusica), 1);

    loop.dispose();
  });

  test('reiniciar deja la casa como nueva', () async {
    final store = MemoriaTamagotchiStore();
    final loop = TamagotchiLoop(store: store, reloj: reloj);
    await loop.cargar();
    loop.activar(TamagotchiAction.darUnAbrazo);
    await pumpEventQueue();
    expect(loop.momentos, 1);

    await loop.reiniciar();

    expect(loop.momentos, 0);
    expect(loop.conexion, 50);
    expect(loop.sebastian.animo, 72);
    expect(loop.hayInformeBienvenida, isFalse);

    loop.dispose();
  });

  test(
    'una escritura lenta no pierde cambios hechos mientras estaba guardando',
    () async {
      final store = _StoreLento();
      final loop = TamagotchiLoop(store: store, reloj: reloj);
      await loop.cargar();

      final primerGuardado = loop.guardar(forzar: true);
      await Future<void>.delayed(Duration.zero);

      expect(store.intentos, hasLength(1));
      expect(store.intentos.single.relacion.momentos, 0);

      loop.activar(TamagotchiAction.jugar);
      loop.activar(TamagotchiAction.ponerMusica);
      expect(loop.momentos, 2);

      store.liberarPrimeraEscritura();
      await primerGuardado;

      expect(store.intentos, hasLength(2));
      expect(store.intentos.last.relacion.momentos, 2);
      expect(store.ultimoEstado?.relacion.momentos, 2);

      loop.dispose();
    },
  );

  test(
    'un almacén que falla no rompe el bucle: sólo avisa por error',
    () async {
      final loop = TamagotchiLoop(store: _StoreRoto(), reloj: reloj);

      await loop.cargar();
      expect(loop.cargado, isTrue);
      expect(loop.error, isNotNull);
      expect(loop.sebastian.animo, 72);

      final resultado = loop.activar(TamagotchiAction.jugar);
      expect(resultado, isNotNull);
      await pumpEventQueue();
      expect(loop.error, isNotNull);

      loop.dispose();
    },
  );
}

class _StoreLento implements TamagotchiStore {
  final Completer<void> _primeraEscritura = Completer<void>();
  final List<TamagotchiState> intentos = <TamagotchiState>[];
  TamagotchiState? ultimoEstado;

  void liberarPrimeraEscritura() {
    if (!_primeraEscritura.isCompleted) _primeraEscritura.complete();
  }

  @override
  Future<TamagotchiState?> leer() async => null;

  @override
  Future<void> escribir(TamagotchiState estado) async {
    intentos.add(estado);
    if (intentos.length == 1) await _primeraEscritura.future;
    ultimoEstado = estado;
  }

  @override
  Future<void> borrar() async {
    ultimoEstado = null;
  }
}

class _StoreRoto implements TamagotchiStore {
  @override
  Future<TamagotchiState?> leer() async => throw StateError('sin disco');

  @override
  Future<void> escribir(TamagotchiState estado) async =>
      throw StateError('sin disco');

  @override
  Future<void> borrar() async => throw StateError('sin disco');
}
