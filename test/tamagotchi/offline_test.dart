import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2026, 5, 1, 20);

  group('progresarSinJugador', () {
    test('una ausencia corta no genera cartel', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(minutes: 3)),
      );

      expect(r.informe, isNull);
      expect(r.estado.vistoEn, base.add(const Duration(minutes: 3)));
      expect(r.estado.sebastian, estado.sebastian);
    });

    test('un reloj que va para atrás no rompe ni castiga', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.subtract(const Duration(hours: 5)),
      );

      expect(r.informe, isNull);
      expect(r.estado.sebastian, estado.sebastian);
      expect(r.estado.relacion, estado.relacion);
    });

    test('tres horas fuera: resumen cálido y stats sanos', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(hours: 3)),
      );
      final informe = r.informe!;

      expect(informe.titulo, 'Mientras no estabas…');
      expect(informe.resumenCorto, contains('3 h'));
      expect(informe.resumenCorto, contains('Noche'));
      expect(informe.momentos, isNotEmpty);
      expect(informe.lineas.length, informe.momentos.length + 1);
      expect(informe.lineas.last, informe.cierre);
      expect(informe.lineas.join(' '), isNot(contains('castigo')));

      for (final gatito in r.estado.gatitos.values) {
        for (final kind in StatKind.values) {
          expect(gatito.stat(kind), greaterThanOrEqualTo(pisoAusencia - 1e-9));
        }
      }
      expect(r.estado.relacion.conexion, greaterThanOrEqualTo(pisoConexion));
      expect(r.estado.relacion.momentos, informe.momentos.length);
      expect(r.estado.vistoEn, base.add(const Duration(hours: 3)));
      expect(informe.llegoAlPiso, isFalse);
    });

    test('de madrugada incluso recuperan energía mientras no estás', () {
      // Se va a las 2:00 y vuelve a las 4:00: durmieron todo el rato.
      final madrugada = DateTime(2026, 5, 1, 2);

      final estado = TamagotchiState.nuevo(madrugada);
      final r = progresarSinJugador(
        estado,
        hasta: madrugada.add(const Duration(hours: 2)),
      );

      expect(
        faseDe(madrugada.add(const Duration(hours: 2))),
        DayPhase.madrugada,
      );
      expect(r.estado.sebastian.energia, greaterThan(estado.sebastian.energia));
      expect(r.estado.maxito.energia, greaterThan(estado.maxito.energia));
      expect(r.informe, isNotNull);
    });

    test('un mes fuera no castiga: todo queda en el piso y la conexión no se hunde', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(days: 30)),
      );
      final informe = r.informe!;

      expect(informe.llegoAlPiso, isTrue);
      expect(informe.cierre, contains('abrazo'));
      expect(informe.momentos.length, lessThanOrEqualTo(8));

      for (final gatito in r.estado.gatitos.values) {
        for (final kind in StatKind.values) {
          expect(gatito.stat(kind), greaterThanOrEqualTo(pisoAusencia - 1e-9));
          expect(gatito.stat(kind), lessThanOrEqualTo(CharacterState.max));
        }
      }
      expect(r.estado.relacion.conexion, greaterThanOrEqualTo(pisoConexion));
      expect(r.estado.relacion.momentos, informe.momentos.length);
    });

    test('el resumen es determinista: mismos datos, mismos momentos', () {
      final estado = TamagotchiState.nuevo(base);

      final a = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(hours: 4)),
      );
      final b = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(hours: 4)),
      );

      expect(
        a.informe!.momentos.map((m) => m.tituloEs).toList(),
        b.informe!.momentos.map((m) => m.tituloEs).toList(),
      );
      expect(a.estado.sebastian.animo, b.estado.sebastian.animo);
      expect(a.informe!.cambioConexion, b.informe!.cambioConexion);
    });

    test('cada ausencia suma como mínimo un momento lindo', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(minutes: 20)),
      );

      expect(r.informe!.momentos.length, 1);
      expect(r.informe!.lineas.first, isNotEmpty);
    });

    test('los cambios del informe son los cambios reales de los stats', () {
      final estado = TamagotchiState.nuevo(base);

      final r = progresarSinJugador(
        estado,
        hasta: base.add(const Duration(hours: 6)),
      );
      final informe = r.informe!;

      for (final id in Characters.ids) {
        for (final kind in StatKind.values) {
          final real =
              r.estado.gatito(id).stat(kind) - estado.gatito(id).stat(kind);
          expect(informe.cambios[id]![kind]!, closeTo(real, 1e-9));
        }
      }
      expect(
        informe.cambioConexion,
        closeTo(r.estado.relacion.conexion - estado.relacion.conexion, 1e-9),
      );
    });
  });

  group('texto del resumen', () {
    test('textoDuracion suena humano', () {
      expect(textoDuracion(const Duration(seconds: 30)), 'un momento');
      expect(textoDuracion(const Duration(minutes: 20)), '20 min');
      expect(textoDuracion(const Duration(hours: 2)), '2 h');
      expect(
        textoDuracion(const Duration(hours: 3, minutes: 20)),
        '3 h 20 min',
      );
      expect(textoDuracion(const Duration(days: 1)), '1 día');
      expect(textoDuracion(const Duration(days: 2)), '2 días');
      expect(textoDuracion(const Duration(days: 2, hours: 4)), '2 días 4 h');
      expect(textoDuracion(const Duration(hours: -3)), 'un momento');
    });

    test('el catálogo de momentos es cálido y sin castigos', () {
      expect(catalogoMomentos, isNotEmpty);
      for (final momento in catalogoMomentos) {
        expect(momento.tituloEs, isNotEmpty);
        expect(momento.lineaEs, isNotEmpty);
        expect(momento.deltas, isNotEmpty);
        for (final delta in momento.deltas.values) {
          expect(delta, greaterThanOrEqualTo(0), reason: momento.tituloEs);
        }
        expect(momento.conexion, greaterThanOrEqualTo(0));
      }
      final texto = catalogoMomentos
          .map((m) => m.lineaEs)
          .join(' ')
          .toLowerCase();
      for (final palabra in <String>[
        'murió',
        'enfermo',
        'castigo',
        'hambre',
        'te extrañó mal',
      ]) {
        expect(texto, isNot(contains(palabra)));
      }
    });
  });
}
