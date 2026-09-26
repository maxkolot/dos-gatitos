import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriva de un gatito', () {
    test('una hora de mañana baja los stats suave y proporcional', () {
      const gatito = CharacterState(
        id: 'x',
        name: 'X',
        animo: 70,
        energia: 80,
        carino: 65,
        social: 60,
      );

      final deriva = derivarGatito(
        gatito,
        const Duration(hours: 1),
        DayPhase.manana,
      );

      expect(deriva.cambios[StatKind.animo], closeTo(-1.2, 1e-9));
      expect(deriva.cambios[StatKind.energia], closeTo(-1.8, 1e-9));
      expect(deriva.cambios[StatKind.carino], closeTo(-0.9, 1e-9));
      expect(deriva.cambios[StatKind.social], closeTo(-1.6, 1e-9));
      expect(deriva.gatito.animo, closeTo(68.8, 1e-9));
    });

    test('de noche se desgastan un poco más rápido que de mañana', () {
      const gatito = CharacterState(id: 'x', name: 'X');

      final manana = derivarGatito(
        gatito,
        const Duration(hours: 2),
        DayPhase.manana,
      );
      final noche = derivarGatito(
        gatito,
        const Duration(hours: 2),
        DayPhase.noche,
      );

      expect(noche.gatito.animo, lessThan(manana.gatito.animo));
    });

    test('de madrugada duermen: la energía se recupera', () {
      const gatito = CharacterState(id: 'x', name: 'X', energia: 40);

      final deriva = derivarGatito(
        gatito,
        const Duration(hours: 2),
        DayPhase.madrugada,
      );

      expect(deriva.cambios[StatKind.energia], greaterThan(0));
      expect(deriva.gatito.energia, closeTo(45, 1e-9));
      expect(deriva.gatito.animo, lessThan(gatito.animo));
    });

    test('nunca se hunde: respeta el piso pedido', () {
      const gatito = CharacterState(id: 'x', name: 'X');

      final vivo = derivarGatito(
        gatito,
        const Duration(days: 40),
        DayPhase.noche,
      );
      final ausente = derivarGatito(
        gatito,
        const Duration(days: 40),
        DayPhase.noche,
        piso: pisoAusencia,
      );

      for (final kind in StatKind.values) {
        expect(vivo.gatito.stat(kind), closeTo(pisoVivo, 1e-9));
        expect(ausente.gatito.stat(kind), closeTo(pisoAusencia, 1e-9));
      }
      expect(pisoVivo, lessThan(pisoAusencia));
    });

    test('una duración muy chica casi no mueve nada', () {
      const gatito = CharacterState(id: 'x', name: 'X');

      final deriva = derivarGatito(
        gatito,
        const Duration(milliseconds: 16),
        DayPhase.tarde,
      );

      expect(deriva.cambios[StatKind.animo]!.abs(), lessThan(0.01));
    });
  });

  group('deriva de la conexión', () {
    test('baja muy despacio', () {
      final relacion = RelationshipState(conexion: 100);

      final deriva = derivarRelacion(
        relacion,
        const Duration(hours: 10),
        DayPhase.manana,
      );

      expect(deriva.relacion.conexion, closeTo(95, 1e-9));
      expect(deriva.cambioConexion, lessThan(0));
    });

    test('nunca se desploma: piso de conexión', () {
      final relacion = RelationshipState(conexion: 100);

      final deriva = derivarRelacion(
        relacion,
        const Duration(days: 400),
        DayPhase.noche,
      );

      expect(deriva.relacion.conexion, closeTo(pisoConexion, 1e-9));
      expect(pisoConexion, greaterThan(0));
    });
  });

  group('deriva de la partida completa', () {
    final ahora = DateTime(2026, 5, 1, 20);

    test('mueve a los dos gatitos y la conexión, sin tocar las fechas', () {
      final estado = TamagotchiState.nuevo(ahora);

      final deriva = derivarEstado(
        estado,
        const Duration(hours: 3),
        DayPhase.noche,
      );

      expect(deriva.cambiosGatitos.length, 2);
      expect(deriva.estado.sebastian.animo, lessThan(estado.sebastian.animo));
      expect(deriva.estado.maxito.social, lessThan(estado.maxito.social));
      expect(deriva.cambioConexion, lessThan(0));
      expect(deriva.estado.creadoEn, estado.creadoEn);
      expect(deriva.estado.vistoEn, estado.vistoEn);
      expect(deriva.cambiosGatitos['sebastian']![StatKind.animo], lessThan(0));
    });

    test('duración cero o negativa no cambia nada', () {
      final estado = TamagotchiState.nuevo(ahora);

      final cero = derivarEstado(estado, Duration.zero, DayPhase.tarde);
      final negativo = derivarEstado(
        estado,
        const Duration(hours: -5),
        DayPhase.tarde,
      );

      expect(cero.estado, estado);
      expect(cero.cambioConexion, 0);
      expect(negativo.estado, estado);
      expect(
        cero.cambiosGatitos.values.every((m) => m.values.every((v) => v == 0)),
        isTrue,
      );
    });

    test('cambiosEntre mide el cambio real', () {
      const antes = CharacterState(id: 'x', name: 'X', animo: 50, social: 50);
      final despues = antes.conStat(StatKind.animo, 70);

      final cambios = cambiosEntre(antes, despues);

      expect(cambios[StatKind.animo], 20);
      expect(cambios[StatKind.social], 0);
    });
  });
}
