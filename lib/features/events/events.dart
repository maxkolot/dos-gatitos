/// Biblioteca «Barcelona Life & Events»: la vida cotidiana de la pareja.
///
/// Uso típico desde el integrador:
///
/// ```dart
/// final engine = EventEngine();
/// final journal = EventJournal();
/// var ctx = EventContext.fromDateTime(
///   DateTime.now(),
///   stats: const StatBlock(),
///   dayIndex: 1,
/// );
/// final event = engine.pickEvent(ctx, random: Random(7));
/// if (event != null) {
///   final outcome = engine.resolveEvent(event, ctx);
///   final dialogue = engine.pickDialogue(ctx, category: event.category);
///   ctx = journal.register(event, ctx).copyWith(stats: outcome.after);
/// }
/// ```
///
/// Ver `README.md` de la carpeta para el contrato completo con el generador.
library;

export 'dialogues.dart';
export 'event_catalog.dart';
export 'event_engine.dart';
export 'models.dart';
export 'offline_recap.dart';
