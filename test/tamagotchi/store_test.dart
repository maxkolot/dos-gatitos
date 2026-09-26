import 'dart:convert';

import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 5, 1, 20);

  group('MemoriaTamagotchiStore', () {
    test('guarda, lee, borra', () async {
      final store = MemoriaTamagotchiStore();
      final estado = TamagotchiState.nuevo(base);

      expect(await store.leer(), isNull);

      await store.escribir(estado);
      final leido = await store.leer();

      expect(leido, isNotNull);
      expect(leido!.sebastian, estado.sebastian);
      expect(leido.maxito, estado.maxito);
      expect(leido.relacion, estado.relacion);
      expect(store.escrituras, 1);
      expect(
        store.lecturas,
        2,
        reason: 'una lectura vacía al principio y una con datos',
      );
      expect(store.crudo, contains('sebastian'));

      await store.borrar();
      expect(await store.leer(), isNull);
    });

    test('un guardado roto se lee como null (no explota)', () async {
      final roto = MemoriaTamagotchiStore(crudoInicial: '{esto no es json');
      expect(await roto.leer(), isNull);

      final sinFecha = MemoriaTamagotchiStore(
        crudoInicial: jsonEncode(<String, Object?>{'version': 1}),
      );
      expect(await sinFecha.leer(), isNull);

      final vacio = MemoriaTamagotchiStore(crudoInicial: '');
      expect(await vacio.leer(), isNull);
    });

    test('el roundtrip conserva stats, relación y últimas acciones', () async {
      final store = MemoriaTamagotchiStore();
      final momento = DateTime(2026, 5, 1, 21);
      final estado = activarAccion(
        TamagotchiState.nuevo(base),
        TamagotchiAction.darUnAbrazo,
        ahora: momento,
      ).estado;

      await store.escribir(estado);
      final leido = await store.leer();

      expect(leido!.relacion.momentos, 1);
      expect(leido.relacion.conexion, closeTo(estado.relacion.conexion, 1e-9));
      expect(leido.sebastian.carino, closeTo(estado.sebastian.carino, 1e-9));
      expect(leido.ultimaVezDe('darUnAbrazo'), momento);
      expect(leido.creadoEn, base);
    });
  });

  group('clave de guardado real', () {
    test('está versionada para poder migrar sin romper partidas', () {
      expect(SharedPrefsTamagotchiStore.clave, 'dos_gatitos.tamagotchi.v1');
      expect(SharedPrefsTamagotchiStore().leer, isNotNull);
    });
  });
}
