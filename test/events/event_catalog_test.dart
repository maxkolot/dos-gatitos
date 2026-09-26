import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dos_gatitos/features/events/events.dart';
import 'package:flutter_test/flutter_test.dart';

/// Palabras latinizadas de ruso que Sebastián puede usar de vez en cuando.
const List<String> kAllowedRussianWords = [
  'privet',
  'spasibo',
  'davai',
  'nyet',
  'blyat',
];

/// No queremos copia en inglés ni en otro idioma en la escena.
const List<String> kForbiddenEnglish = [
  'the',
  'and',
  'with',
  'hello',
  'goodbye',
  'please',
  'thanks',
  'because',
  'morning',
  'night',
];

/// Tono: sin agresión ni humillación.
const List<String> kForbiddenTone = [
  'idiota',
  'estúpido',
  'estupido',
  'inútil',
  'inutil',
  'callate',
  'cállate',
  'odio',
  'maldito',
];

void main() {
  final engine = EventEngine();
  final catalog = kEventCatalog;

  group('catálogo de eventos', () {
    test('tiene al menos 40 eventos con ids únicos', () {
      expect(catalog.length, greaterThanOrEqualTo(40));
      final ids = catalog.map((e) => e.id).toSet();
      expect(ids.length, catalog.length);
    });

    test('cubre todas las categorías de la vida en Barcelona', () {
      final used = catalog.map((e) => e.category).toSet();
      expect(used, containsAll(EventCategory.values));
      final byCategory = <EventCategory, int>{};
      for (final event in catalog) {
        byCategory.update(event.category, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(byCategory[EventCategory.piso], greaterThanOrEqualTo(4));
      expect(byCategory[EventCategory.musica], greaterThanOrEqualTo(4));
      expect(byCategory[EventCategory.vino], greaterThanOrEqualTo(3));
      expect(byCategory[EventCategory.cafe], greaterThanOrEqualTo(3));
      expect(byCategory[EventCategory.lluvia], greaterThanOrEqualTo(3));
      expect(byCategory[EventCategory.balcon], greaterThanOrEqualTo(3));
      expect(byCategory[EventCategory.supermercado], greaterThanOrEqualTo(3));
      expect(byCategory[EventCategory.metro], greaterThanOrEqualTo(2));
    });

    test('tiene las siete salidas de la ciudad y son raras (peso <= 6)', () {
      const outings = [
        EventCategory.gracia,
        EventCategory.eixample,
        EventCategory.raval,
        EventCategory.barceloneta,
        EventCategory.montjuic,
        EventCategory.sitges,
      ];
      for (final outing in outings) {
        final events =
            catalog.where((e) => e.category == outing).toList(growable: false);
        expect(events, isNotEmpty, reason: 'falta salida ${outing.label}');
        expect(events.every((e) => e.weight <= 6), isTrue,
            reason: '${outing.label} debería ser plan raro');
      }
      expect(kOutingEvents.length, greaterThanOrEqualTo(15));
    });

    test('los eventos dependen de hora, ánimo y conexión', () {
      final withTime =
          catalog.where((e) => e.conditions.timeOfDay.isNotEmpty).length;
      final withMood = catalog
          .where((e) =>
              e.conditions.moodAtLeast != null || e.conditions.moodAtMost != null)
          .length;
      final withBond =
          catalog.where((e) => e.conditions.bondAtLeast != null).length;
      final withEnergy = catalog
          .where((e) =>
              e.conditions.energyAtMost != null || e.conditions.energyAtLeast != null)
          .length;

      expect(withTime, greaterThanOrEqualTo(12));
      expect(withMood, greaterThanOrEqualTo(4));
      expect(withBond, greaterThanOrEqualTo(5));
      expect(withEnergy, greaterThanOrEqualTo(2));

      final madrugada = catalog.where((e) =>
          e.conditions.timeOfDay.length == 1 &&
          e.conditions.timeOfDay.single == TimeOfDaySlot.madrugada);
      final manana = catalog.where((e) =>
          e.conditions.timeOfDay.length == 1 &&
          e.conditions.timeOfDay.single == TimeOfDaySlot.manana);
      expect(madrugada, isNotEmpty);
      expect(manana, isNotEmpty);
      expect(
        catalog.where((e) => e.conditions.weekendOnly),
        isNotEmpty,
      );
    });

    test('cada evento tiene título, escena y diálogo en español', () {
      for (final event in catalog) {
        expect(event.title.trim(), isNotEmpty, reason: event.id);
        expect(event.scene.trim().length, greaterThan(30), reason: event.id);
        expect(event.scene.trim(), endsWith('.'), reason: event.id);
        expect(event.lines, isNotEmpty, reason: event.id);
        expect(event.tags, isNotEmpty, reason: event.id);
        expect(event.weight, inInclusiveRange(1, 10), reason: event.id);
        expect(event.cooldown, greaterThan(0), reason: event.id);
      }
    });

    test('la copia es española, sin cirílico y sin inglés suelto', () {
      final texts = <String>[
        for (final event in catalog) ...[
          event.title,
          event.scene,
          for (final line in event.lines) line.text,
        ],
        for (final dialogue in kJointDialogues) ...[
          dialogue.spark,
          for (final line in dialogue.lines) line.text,
        ],
        for (final recap in kOfflineRecaps) recap.text,
      ];

      final cyrillic = RegExp(r'[\u0400-\u04FF]');
      for (final text in texts) {
        expect(cyrillic.hasMatch(text), isFalse, reason: text);
        for (final word in kForbiddenEnglish) {
          expect(
            _hasWord(text, word),
            isFalse,
            reason: 'palabra inglesa «$word» en: $text',
          );
        }
        for (final word in kForbiddenTone) {
          expect(
            text.toLowerCase().contains(word),
            isFalse,
            reason: 'tono no cariñoso «$word» en: $text',
          );
        }
      }
    });

    test('Sebastián usa el ruso latinizado poco y solo con permiso', () {
      final sebastianLines = <String>[
        for (final event in catalog)
          for (final line in event.lines)
            if (line.speaker == LineSpeaker.sebastian) line.text.toLowerCase(),
        for (final dialogue in kJointDialogues)
          for (final line in dialogue.lines)
            if (line.speaker == LineSpeaker.sebastian) line.text.toLowerCase(),
      ];
      expect(sebastianLines.length, greaterThan(40));

      var withRussian = 0;
      for (final line in sebastianLines) {
        final hasRussian =
            kAllowedRussianWords.any((word) => line.contains(word));
        if (hasRussian) {
          withRussian++;
          expect(
            kAllowedRussianWords.any((word) => line.contains(word)),
            isTrue,
            reason: line,
          );
        }
      }
      final ratio = withRussian / sebastianLines.length;
      expect(ratio, greaterThanOrEqualTo(0.03));
      expect(ratio, lessThanOrEqualTo(0.12));
    });

    test('Maxito nunca usa palabras rusas', () {
      for (final event in catalog) {
        for (final line in event.lines) {
          if (line.speaker != LineSpeaker.maxito) continue;
          for (final word in kAllowedRussianWords) {
            expect(line.text.toLowerCase().contains(word), isFalse,
                reason: line.text);
          }
        }
      }
    });
  });

  group('cambios de estado', () {
    test('ningún evento mueve más de ±${StatDelta.maxStep.toInt()} puntos', () {
      var moving = 0;
      for (final event in catalog) {
        final d = event.delta;
        for (final value in [d.mood, d.energy, d.social, d.bond]) {
          expect(value.abs(), lessThanOrEqualTo(StatDelta.maxStep),
              reason: event.id);
        }
        if (!d.isZero) moving++;
      }
      expect(moving, greaterThanOrEqualTo(catalog.length - 3));
    });

    test('la mayoría de las escenas suman ánimo y conexión', () {
      final moodPositive =
          catalog.where((e) => e.delta.mood > 0).length;
      final bondPositive = catalog.where((e) => e.delta.bond > 0).length;
      expect(moodPositive, greaterThan(catalog.length * 0.7));
      expect(bondPositive, greaterThan(catalog.length * 0.5));
    });

    test('los estados quedan siempre entre 0 y 100', () {
      final extremeLow = const StatBlock(mood: 1, energy: 0, social: 2, bond: 0);
      final extremeHigh =
          const StatBlock(mood: 99, energy: 100, social: 98, bond: 100);
      final ctxLow = EventContext(
        timeOfDay: TimeOfDaySlot.noche,
        stats: extremeLow,
      );
      final ctxHigh = EventContext(
        timeOfDay: TimeOfDaySlot.noche,
        stats: extremeHigh,
      );
      for (final event in catalog) {
        final low = engine.resolveEvent(event, ctxLow).after;
        final high = engine.resolveEvent(event, ctxHigh).after;
        for (final stats in [low, high]) {
          expect(stats.mood, inInclusiveRange(0, 100));
          expect(stats.energy, inInclusiveRange(0, 100));
          expect(stats.social, inInclusiveRange(0, 100));
          expect(stats.bond, inInclusiveRange(0, 100));
        }
      }
    });
  });

  group('motor de eventos', () {
    final contexts = <EventContext>[
      for (final slot in TimeOfDaySlot.values)
        for (final mood in [20.0, 60.0, 85.0])
          for (final bond in [10.0, 50.0, 90.0])
            for (final weekend in [false, true])
              EventContext(
                timeOfDay: slot,
                stats: StatBlock(mood: mood, bond: bond),
                isWeekend: weekend,
                dayIndex: 5,
              ),
    ];

    test('nunca elige un evento con condiciones incumplidas', () {
      for (final ctx in contexts) {
        final pickable = engine.pickableEvents(ctx);
        expect(pickable, isNotEmpty, reason: ctx.toString());
        for (final event in pickable) {
          expect(engine.accepts(event, ctx), isTrue);
          final when = event.conditions.timeOfDay;
          if (when.isNotEmpty) expect(when, contains(ctx.timeOfDay));
        }
      }
    });

    test('es determinista con la misma semilla', () {
      final picks = <String>[];
      for (final ctx in contexts) {
        final first = engine.pickEvent(ctx, random: Random(42));
        final second = engine.pickEvent(ctx, random: Random(42));
        expect(first?.id, second?.id);
        picks.add(first!.id);
      }
      expect(picks.length, contexts.length);
    });

    test('respeta el enfriamiento de los eventos ya vistos', () {
      final ctx = EventContext(
        timeOfDay: TimeOfDaySlot.noche,
        stats: const StatBlock(),
        isWeekend: true,
        dayIndex: 5,
        recentEventIds: kEventCatalog.map((e) => e.id).toSet(),
      );
      expect(engine.pickEvent(ctx, random: Random(1)), isNull);
      expect(engine.pickableEvents(ctx), isEmpty);
    });

    test('un evento de madrugada no sale a las once de la mañana', () {
      final morning = EventContext(
        timeOfDay: TimeOfDaySlot.manana,
        stats: const StatBlock(),
        isWeekend: true,
        dayIndex: 5,
      );
      final pickable = engine.pickableEvents(morning).map((e) => e.id).toSet();
      for (final event in catalog) {
        final when = event.conditions.timeOfDay;
        if (when.length == 1 && when.single == TimeOfDaySlot.madrugada) {
          expect(pickable, isNot(contains(event.id)), reason: event.id);
        }
      }
      final metro = pickable.where((id) => id.startsWith('metro_ultimo'));
      expect(metro, isEmpty);
    });

    test('las salidas pesan más el finde con conexión alta', () {
      const outing = GameEvent(
        id: 'salida_fake',
        category: EventCategory.sitges,
        title: 'Salida de prueba',
        scene: 'Escena de prueba para comparar pesos relativos del motor.',
        delta: StatDelta(mood: 1),
        weight: 4,
      );
      final weekday = engine.weightOf(
        outing,
        const EventContext(
          timeOfDay: TimeOfDaySlot.tarde,
          stats: StatBlock(social: 30, bond: 60),
        ),
      );
      final weekend = engine.weightOf(
        outing,
        const EventContext(
          timeOfDay: TimeOfDaySlot.tarde,
          stats: StatBlock(social: 80, bond: 80),
          isWeekend: true,
        ),
      );
      expect(weekend, greaterThan(weekday));
    });

    test('el diario evita repetir la última escena', () {
      final journal = EventJournal();
      var ctx = EventContext(
        timeOfDay: TimeOfDaySlot.noche,
        stats: const StatBlock(),
        isWeekend: true,
        dayIndex: 3,
      );
      final played = <String>[];
      for (var i = 0; i < 12; i++) {
        final event = engine.pickEvent(ctx, random: Random(i));
        expect(event, isNotNull);
        expect(played, isNot(contains(event!.id)));
        played.add(event.id);
        ctx = journal.register(event, ctx);
      }
      expect(journal.eventsPlayed, 12);
      expect(played.toSet().length, 12);
    });
  });

  group('charlas conjuntas', () {
    test('hay al menos 6 y todas se pisan la frase', () {
      expect(kJointDialogues.length, greaterThanOrEqualTo(6));
      for (final dialogue in kJointDialogues) {
        expect(dialogue.hasInterruption, isTrue, reason: dialogue.id);
        expect(dialogue.lines.length, greaterThanOrEqualTo(4));
        expect(dialogue.spark.trim(), isNotEmpty);
        final speakers = dialogue.lines.map((l) => l.speaker).toSet();
        expect(speakers, contains(LineSpeaker.sebastian));
        expect(speakers, contains(LineSpeaker.maxito));
      }
    });

    test('las interrupciones siempre siguen a otra línea de la pareja', () {
      for (final dialogue in kJointDialogues) {
        for (var i = 0; i < dialogue.lines.length; i++) {
          final line = dialogue.lines[i];
          if (!line.interruptsPrevious) continue;
          expect(i, greaterThan(0), reason: '${dialogue.id}: no hay nada que pisar');
          expect(dialogue.lines[i - 1].speaker, isNot(line.speaker),
              reason: dialogue.id);
        }
      }
    });

    test('el motor propone charlas que encajan con la escena', () {
      final ctx = EventContext(
        timeOfDay: TimeOfDaySlot.noche,
        stats: const StatBlock(bond: 70),
      );
      expect(engine.pickDialogue(ctx, random: Random(3)), isNotNull);
      expect(engine.pickDialogue(ctx, category: EventCategory.vino), isNotNull);
      expect(dialoguesFor(EventCategory.supermercado), isNotEmpty);
    });
  });

  group('«Mientras no estabas…»', () {
    test('hay al menos 15 recuerdos cortos con prefijo', () {
      expect(kOfflineRecaps.length, greaterThanOrEqualTo(15));
      final ids = kOfflineRecaps.map((r) => r.id).toSet();
      expect(ids.length, kOfflineRecaps.length);
      for (final recap in kOfflineRecaps) {
        expect(recap.display, startsWith(OfflineRecap.prefix));
        expect(recap.display.length, lessThan(160));
        expect(recap.text, endsWith('.'));
        for (final value in [
          recap.delta.mood,
          recap.delta.energy,
          recap.delta.social,
          recap.delta.bond,
        ]) {
          expect(value.abs(), lessThanOrEqualTo(StatDelta.maxStep));
        }
      }
    });

    test('el resumen cambia de tamaño según cuánto tiempo estuvo fuera', () {
      final now = DateTime(2026, 3, 14, 23, 30); // sábado de noche
      final short = engine.buildOfflineReport(
        stats: const StatBlock(),
        away: const Duration(minutes: 40),
        random: Random(5),
        now: now,
      );
      final long = engine.buildOfflineReport(
        stats: const StatBlock(),
        away: const Duration(hours: 20),
        random: Random(5),
        now: now,
      );
      expect(short.recaps.length, 1);
      expect(long.recaps.length, 3);
      expect(short.awayHours, 0);
      expect(long.awayHours, 20);
    });

    test('respeta las condiciones de hora, ánimo y conexión', () {
      final madrugada = EventContext(
        timeOfDay: TimeOfDaySlot.madrugada,
        stats: const StatBlock(mood: 20, bond: 30),
      );
      final pickable = engine.pickableRecaps(madrugada);
      expect(pickable, isNotEmpty);
      for (final recap in pickable) {
        final when = recap.conditions.timeOfDay;
        if (when.isNotEmpty) expect(when, contains(TimeOfDaySlot.madrugada));
        final bondAtLeast = recap.conditions.bondAtLeast;
        if (bondAtLeast != null) expect(madrugada.stats.bond, greaterThanOrEqualTo(bondAtLeast));
        final moodAtMost = recap.conditions.moodAtMost;
        if (moodAtMost != null) {
          expect(madrugada.stats.moodLevel.index, lessThanOrEqualTo(moodAtMost.index));
        }
      }
      expect(
        engine.pickableRecaps(madrugada).map((r) => r.id),
        contains('off_abrazo_largo'),
      );
    });

    test('el cambio total del resumen se queda suave', () {
      final report = engine.buildOfflineReport(
        stats: const StatBlock(),
        away: const Duration(hours: 30),
        random: Random(11),
        now: DateTime(2026, 3, 14, 23, 30),
        maxRecaps: 3,
      );
      final total = report.totalDelta;
      for (final value in [total.mood, total.energy, total.social, total.bond]) {
        expect(value.abs(), lessThanOrEqualTo(kOfflineTotalSoftCap));
      }
      expect(report.lines.length, report.recaps.length);
      expect(report.lines.every((l) => l.startsWith(OfflineRecap.prefix)), isTrue);
      expect(report.after.mood, inInclusiveRange(0, 100));
    });
  });

  group('contrato para el generador', () {
    test('describeCatalog expone todo el contenido', () {
      final description = engine.describeCatalog();
      expect(description['contractVersion'], kEventsContractVersion);
      expect(description['eventCount'], catalog.length);
      expect(description['dialogueCount'], kJointDialogues.length);
      expect(description['offlineRecapCount'], kOfflineRecaps.length);
      final events = description['events'] as List<dynamic>;
      expect(events.length, catalog.length);
      final first = events.first as Map<String, dynamic>;
      expect(first.keys, containsAll(['id', 'scene', 'conditions', 'delta', 'lines']));
    });

    test('assets/content/events.json está sincronizado con el catálogo', () {
      final file = File('assets/content/events.json');
      expect(file.existsSync(), isTrue,
          reason: 'ejecutá: dart run tool/export_events.dart');
      final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['contractVersion'], kEventsContractVersion);
      expect(decoded['eventCount'], catalog.length);
      final ids = (decoded['events'] as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['id'])
          .toList();
      expect(ids, catalog.map((e) => e.id).toList());
      expect((decoded['offlineRecaps'] as List<dynamic>).length,
          kOfflineRecaps.length);
      expect((decoded['dialogues'] as List<dynamic>).length,
          kJointDialogues.length);
    });
  });

  group('franjas del día', () {
    test('la hora se traduce a la franja correcta', () {
      expect(TimeOfDaySlot.fromHour(3), TimeOfDaySlot.madrugada);
      expect(TimeOfDaySlot.fromHour(9), TimeOfDaySlot.manana);
      expect(TimeOfDaySlot.fromHour(13), TimeOfDaySlot.mediodia);
      expect(TimeOfDaySlot.fromHour(18), TimeOfDaySlot.tarde);
      expect(TimeOfDaySlot.fromHour(22), TimeOfDaySlot.noche);
      expect(TimeOfDaySlot.fromHour(0), TimeOfDaySlot.noche);
    });

    test('los niveles de ánimo y conexión acompañan a los estados', () {
      expect(MoodLevel.fromMood(10), MoodLevel.bajo);
      expect(MoodLevel.fromMood(50), MoodLevel.normal);
      expect(MoodLevel.fromMood(90), MoodLevel.alto);
      expect(ConnectionLevel.fromBond(10), ConnectionLevel.distante);
      expect(ConnectionLevel.fromBond(45), ConnectionLevel.tibia);
      expect(ConnectionLevel.fromBond(70), ConnectionLevel.cercana);
      expect(ConnectionLevel.fromBond(95), ConnectionLevel.fusionados);
    });

    test('EventContext.fromDateTime arma el contexto del finde', () {
      final ctx = EventContext.fromDateTime(
        DateTime(2026, 3, 14, 23, 30),
        stats: const StatBlock(bond: 80),
        dayIndex: 2,
      );
      expect(ctx.timeOfDay, TimeOfDaySlot.noche);
      expect(ctx.isWeekend, isTrue);
      expect(ctx.dayIndex, 2);
    });
  });
}

/// Busca una palabra completa teniendo en cuenta acentos (así «Andén» no
/// cuenta como la palabra inglesa «and»).
bool _hasWord(String text, String word) => RegExp(
      '(?<![\\p{L}])$word(?![\\p{L}])',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(text);
