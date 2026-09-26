import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 5, 1, 20);

  group('catálogo de acciones', () {
    test('las siete acciones están definidas, en español y con icono', () {
      expect(TamagotchiAction.values.length, 7);
      expect(catalogoAcciones.length, TamagotchiAction.values.length);

      for (final accion in TamagotchiAction.values) {
        final spec = specDe(accion);
        expect(spec.labelEs, isNotEmpty, reason: accion.name);
        expect(spec.descripcionEs, isNotEmpty, reason: accion.name);
        expect(spec.icono, isNotEmpty, reason: accion.name);
        expect(spec.deltas, isNotEmpty, reason: accion.name);
      }
    });

    test('los títulos son los pedidos por el diseño', () {
      expect(
        TamagotchiAction.values.map((a) => specDe(a).labelEs).toList(),
        <String>[
          'Poner música',
          'Servir vino',
          'Hablar',
          'Dar un abrazo',
          'Jugar',
          'Cenar milanesas',
          'Preguntar',
        ],
      );
    });

    test('ninguna acción baja Ánimo, Cariño, Social ni Conexión', () {
      for (final accion in TamagotchiAction.values) {
        final spec = specDe(accion);
        for (final entrada in spec.deltas.entries) {
          if (entrada.key.esGasto) {
            // la única que devuelve energía: comer (Sebas cocina milanesas)
            if (accion == TamagotchiAction.cenar) {
              expect(entrada.value, greaterThan(0), reason: 'cenar recupera energía');
              continue;
            }
            expect(
              entrada.value,
              lessThanOrEqualTo(0),
              reason: '${spec.labelEs}: la energía es gasto',
            );
          } else {
            expect(
              entrada.value,
              greaterThan(0),
              reason: '${spec.labelEs} no puede bajar ${entrada.key.labelEs}',
            );
          }
        }
        expect(spec.conexion, greaterThan(0), reason: spec.labelEs);
      }
    });
  });

  group('activarAccion', () {
    test(
      'poner música sube ánimo y social de los dos y gasta poca energía',
      () {
        final estado = TamagotchiState.nuevo(base);

        final r = activarAccion(
          estado,
          TamagotchiAction.ponerMusica,
          ahora: base,
        );

        expect(r.estado.sebastian.animo, closeTo(80, 1e-6));
        expect(r.estado.maxito.animo, closeTo(86, 1e-6));
        expect(r.estado.sebastian.social, closeTo(64, 1e-6));
        expect(
          r.resultado.cambios['sebastian']![StatKind.energia]!,
          closeTo(-4, 1e-6),
        );
        expect(r.estado.relacion.conexion, closeTo(52, 1e-6));
        expect(r.resultado.huboCambio, isTrue);
        expect(r.resultado.labelEs, 'Poner música');
        expect(r.resultado.reducido, isFalse);
      },
    );

    test('el abrazo suma Cariño y Conexión a los dos', () {
      final estado = TamagotchiState.nuevo(base);

      final r = activarAccion(
        estado,
        TamagotchiAction.darUnAbrazo,
        ahora: base,
      );

      expect(r.estado.sebastian.carino, closeTo(76, 1e-6));
      expect(r.estado.maxito.carino, closeTo(78, 1e-6));
      expect(r.resultado.cambioConexion, closeTo(6, 1e-6));
      expect(r.estado.relacion.momentos, 1);
      expect(r.estado.ultimaVezDe('darUnAbrazo'), base);
    });

    test('hablar con uno le da más al elegido y algo al otro', () {
      final estado = TamagotchiState.nuevo(base);

      final r = activarAccion(
        estado,
        TamagotchiAction.hablar,
        conQuien: 'maxito',
        ahora: base,
      );

      expect(r.resultado.conQuien, 'maxito');
      final alElegido = r.resultado.cambios['maxito']![StatKind.social]!;
      final alOtro = r.resultado.cambios['sebastian']![StatKind.social]!;
      expect(alElegido, closeTo(9, 1e-6));
      expect(alOtro, closeTo(5.4, 1e-6));
      expect(alElegido, greaterThan(alOtro));
    });

    test('conQuien desconocido cae en el primer gatito, sin explotar', () {
      final estado = TamagotchiState.nuevo(base);

      final r = activarAccion(
        estado,
        TamagotchiAction.preguntar,
        conQuien: 'fantasma',
        ahora: base,
      );

      expect(r.resultado.conQuien, 'sebastian');
    });

    test('por mucho mimo que haya, nada pasa de 100', () {
      final estado = TamagotchiState.nuevo(base).copyWith(
        gatitos: const <String, CharacterState>{
          'sebastian': CharacterState(
            id: 'sebastian',
            name: 'Sebastián',
            animo: 99,
            energia: 99,
            carino: 99,
            social: 99,
          ),
          'maxito': CharacterState(
            id: 'maxito',
            name: 'Maxito',
            animo: 99,
            energia: 99,
            carino: 99,
            social: 99,
          ),
        },
        relacion: const RelationshipState(conexion: 99.5),
      );

      final r = activarAccion(
        estado,
        TamagotchiAction.darUnAbrazo,
        ahora: base,
      );

      for (final gatito in r.estado.gatitos.values) {
        for (final kind in StatKind.values) {
          expect(gatito.stat(kind), lessThanOrEqualTo(CharacterState.max));
        }
      }
      expect(r.estado.relacion.conexion, closeTo(RelationshipState.max, 1e-9));
      expect(r.resultado.cambioConexion, closeTo(0.5, 1e-9));
    });

    test('la energía nunca se gasta por debajo de su piso', () {
      final estado = TamagotchiState.nuevo(base).copyWith(
        gatitos: const <String, CharacterState>{
          'sebastian': CharacterState(
            id: 'sebastian',
            name: 'Sebastián',
            energia: 12,
          ),
          'maxito': CharacterState(id: 'maxito', name: 'Maxito', energia: 45),
        },
      );

      final r = activarAccion(estado, TamagotchiAction.jugar, ahora: base);

      expect(r.estado.sebastian.energia, closeTo(pisoEnergiaAccion, 1e-9));
      expect(r.estado.maxito.energia, closeTo(39, 1e-9));
    });

    test('repetir la misma acción enseguida rinde menos, pero nunca cero', () {
      final estado = TamagotchiState.nuevo(base);

      final primera = activarAccion(
        estado,
        TamagotchiAction.preguntar,
        conQuien: 'sebastian',
        ahora: base,
      );
      final repetida = activarAccion(
        primera.estado,
        TamagotchiAction.preguntar,
        conQuien: 'sebastian',
        ahora: base,
      );

      expect(primera.resultado.factor, 1);
      expect(repetida.resultado.factor, closeTo(0.5, 1e-9));
      expect(repetida.resultado.reducido, isTrue);
      expect(repetida.resultado.nota, isNotNull);

      final gananciaPrimera =
          primera.resultado.cambios['sebastian']![StatKind.social]!;
      final gananciaRepetida =
          repetida.resultado.cambios['sebastian']![StatKind.social]!;
      expect(gananciaRepetida, greaterThan(0));
      expect(gananciaRepetida, lessThan(gananciaPrimera));
    });

    test('a los 30 minutos la acción vuelve a rendir entera', () {
      final estado = TamagotchiState.nuevo(base);

      final primera = activarAccion(
        estado,
        TamagotchiAction.ponerMusica,
        ahora: base,
      );
      final despues = activarAccion(
        primera.estado,
        TamagotchiAction.ponerMusica,
        ahora: base.add(const Duration(minutes: 30)),
      );

      expect(despues.resultado.factor, 1);
      expect(despues.resultado.reducido, isFalse);
    });

    test('a mitad de ventana el factor es intermedio (curva suave)', () {
      final spec = specDe(TamagotchiAction.ponerMusica);

      expect(
        factorDeRepeticion(base, base.add(const Duration(minutes: 15)), spec),
        closeTo(0.75, 1e-9),
      );
      expect(factorDeRepeticion(null, base, spec), 1);
      expect(
        factorDeRepeticion(base, base.subtract(const Duration(hours: 1)), spec),
        1,
      );
    });

    test('accionPorNombre es la clave del guardado', () {
      expect(accionPorNombre('jugar'), TamagotchiAction.jugar);
      expect(accionPorNombre('bailar'), isNull);
      expect(accionPorNombre(null), isNull);
      for (final accion in TamagotchiAction.values) {
        expect(accionPorNombre(accion.name), accion);
      }
    });

    test('una acción tras la otra: la conexión suma una vez por acción', () {
      var estado = TamagotchiState.nuevo(base);

      estado = activarAccion(
        estado,
        TamagotchiAction.servirVino,
        ahora: base,
      ).estado;
      estado = activarAccion(
        estado,
        TamagotchiAction.jugar,
        ahora: base,
      ).estado;

      expect(estado.relacion.momentos, 2);
      expect(estado.relacion.conexion, closeTo(56, 1e-6));
      expect(estado.ultimasAcciones.length, 2);
    });
  });
}
