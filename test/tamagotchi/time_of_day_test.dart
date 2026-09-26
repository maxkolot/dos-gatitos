import 'package:dos_gatitos/features/tamagotchi/tamagotchi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('franjas del día', () {
    test('los límites de hora son los esperados', () {
      expect(faseDeHora(0), DayPhase.madrugada);
      expect(faseDeHora(5), DayPhase.madrugada);
      expect(faseDeHora(6), DayPhase.manana);
      expect(faseDeHora(11), DayPhase.manana);
      expect(faseDeHora(12), DayPhase.tarde);
      expect(faseDeHora(17), DayPhase.tarde);
      expect(faseDeHora(18), DayPhase.noche);
      expect(faseDeHora(23), DayPhase.noche);
    });

    test('una hora rara no rompe nada', () {
      expect(faseDeHora(-3), DayPhase.madrugada);
      expect(faseDeHora(99), DayPhase.noche);
    });

    test('faseDe mira la hora del momento', () {
      expect(faseDe(DateTime(2026, 5, 1, 8, 30)), DayPhase.manana);
      expect(faseDe(DateTime(2026, 5, 1, 22, 5)), DayPhase.noche);
    });

    test('los nombres y saludos están en español', () {
      expect(DayPhase.values.map((f) => f.labelEs).toList(), <String>[
        'Madrugada',
        'Mañana',
        'Tarde',
        'Noche',
      ]);
      expect(DayPhase.manana.saludo, 'Buenos días');
      expect(DayPhase.tarde.saludo, 'Buenas tardes');
      expect(DayPhase.noche.saludo, 'Buenas noches');
      expect(DayPhase.madrugada.saludo, 'Buena madrugada');
    });

    test(
      'de madrugada descansan: el desgaste es el más lento y la energía sube',
      () {
        expect(DayPhase.madrugada.esDescanso, isTrue);
        expect(DayPhase.noche.esDescanso, isFalse);
        expect(
          DayPhase.madrugada.multiplicador,
          lessThan(DayPhase.manana.multiplicador),
        );
        expect(
          DayPhase.noche.multiplicador,
          greaterThan(DayPhase.tarde.multiplicador),
        );
      },
    );
  });
}
