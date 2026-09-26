/// Motor de eventos: elige el momento del día, valida condiciones y aplica
/// cambios suaves a los estados.
///
/// Contrato pensado para el integrador y para el generador de contenido:
///
/// * [EventEngine.pickableEvents] — qué eventos pueden salir ahora (lista estable).
/// * [EventEngine.pickEvent] — uno al azar por peso, determinista con semilla.
/// * [EventEngine.resolveEvent] — texto listo para mostrar + estados nuevos.
/// * [EventEngine.pickDialogue] — charla conjunta que encaja con la escena.
/// * [EventEngine.buildOfflineReport] — resumen «Mientras no estabas…».
/// * [EventEngine.describeCatalog] — mapa con el catálogo completo (JSON-friendly).
///
/// No hay red, no hay UI, no hay acceso a disco: todo es Dart puro y testeable.
library;

import 'dart:math';

import 'dialogues.dart';
import 'event_catalog.dart';
import 'models.dart';
import 'offline_recap.dart';

/// Versión del contrato de datos que expone esta biblioteca.
const int kEventsContractVersion = 1;

/// Banda de seguridad de los cambios totales de un resumen offline.
const double kOfflineTotalSoftCap = 9;

/// Motor de la vida cotidiana de Sebastián y Maxito.
class EventEngine {
  EventEngine({
    List<GameEvent>? catalog,
    List<JointDialogue>? dialogues,
    List<OfflineRecap>? recaps,
  })  : catalog = List.unmodifiable(catalog ?? kEventCatalog),
        dialogues = List.unmodifiable(dialogues ?? kJointDialogues),
        recaps = List.unmodifiable(recaps ?? kOfflineRecaps);

  final List<GameEvent> catalog;
  final List<JointDialogue> dialogues;
  final List<OfflineRecap> recaps;

  /// `true` si el evento puede salir en este contexto.
  bool accepts(GameEvent event, EventContext ctx) {
    if (ctx.recentEventIds.contains(event.id)) return false;

    final when = event.conditions.timeOfDay;
    if (when.isNotEmpty && !when.contains(ctx.timeOfDay)) return false;

    final mood = ctx.stats.moodLevel;
    final moodAtLeast = event.conditions.moodAtLeast;
    if (moodAtLeast != null && mood.index < moodAtLeast.index) return false;
    final moodAtMost = event.conditions.moodAtMost;
    if (moodAtMost != null && mood.index > moodAtMost.index) return false;

    final energyAtMost = event.conditions.energyAtMost;
    if (energyAtMost != null && ctx.stats.energy > energyAtMost) return false;
    final energyAtLeast = event.conditions.energyAtLeast;
    if (energyAtLeast != null && ctx.stats.energy < energyAtLeast) return false;

    final bondAtLeast = event.conditions.bondAtLeast;
    if (bondAtLeast != null && ctx.stats.bond < bondAtLeast) return false;
    final socialAtLeast = event.conditions.socialAtLeast;
    if (socialAtLeast != null && ctx.stats.social < socialAtLeast) return false;

    if (event.conditions.weekendOnly && !ctx.isWeekend) return false;
    if (event.conditions.weekdayOnly && ctx.isWeekend) return false;
    if (ctx.dayIndex < event.conditions.minDayIndex) return false;

    return true;
  }

  /// Eventos disponibles ahora mismo, en el orden estable del catálogo.
  List<GameEvent> pickableEvents(EventContext ctx) =>
      catalog.where((event) => accepts(event, ctx)).toList(growable: false);

  /// Evento elegido por peso, o `null` si no queda nada disponible.
  ///
  /// Con la misma semilla y el mismo contexto devuelve siempre lo mismo.
  GameEvent? pickEvent(EventContext ctx, {Random? random}) {
    final options = pickableEvents(ctx);
    if (options.isEmpty) return null;
    final rng = random ?? Random();
    final weights = options.map((event) => weightOf(event, ctx)).toList();
    return options[_weightedIndex(weights, rng)];
  }

  /// Peso efectivo: el peso del evento, con pequeños ajustes de afinidad.
  double weightOf(GameEvent event, EventContext ctx) {
    var weight = event.weight.toDouble();
    if (event.isOuting) {
      // Las salidas son raras, pero se permiten más cuando hay ánimo y plata social.
      weight *= 0.7 + (ctx.stats.social / 100) * 0.8;
      if (ctx.isWeekend) weight *= 1.35;
    }
    if (event.id.startsWith('piso_')) {
      weight *= 0.9 + (100 - ctx.stats.social) / 400;
    }
    // Alternar piso y calle: repetir la última categoría baja el peso.
    if (ctx.recentCategories.isNotEmpty &&
        ctx.recentCategories.last == event.category) {
      weight *= 0.35;
    }
    return weight.clamp(0.05, 100).toDouble();
  }

  int _weightedIndex(List<double> weights, Random rng) {
    final total = weights.fold<double>(0, (sum, w) => sum + w);
    var ticket = rng.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      ticket -= weights[i];
      if (ticket <= 0) return i;
    }
    return weights.length - 1;
  }

  /// Resuelve un evento: aplica deltas suaves y devuelve el texto a mostrar.
  EventOutcome resolveEvent(GameEvent event, EventContext ctx) {
    final before = ctx.stats;
    final after = before.apply(_soften(event.delta));
    return EventOutcome(
      event: event,
      before: before,
      after: after,
      lines: event.lines,
    );
  }

  /// Ninguna escena suelta mueve más de [StatDelta.maxStep] por estado.
  StatDelta _soften(StatDelta delta) => StatDelta(
        mood: delta.mood.clamp(-StatDelta.maxStep, StatDelta.maxStep).toDouble(),
        energy:
            delta.energy.clamp(-StatDelta.maxStep, StatDelta.maxStep).toDouble(),
        social:
            delta.social.clamp(-StatDelta.maxStep, StatDelta.maxStep).toDouble(),
        bond: delta.bond.clamp(-StatDelta.maxStep, StatDelta.maxStep).toDouble(),
      );

  /// Charla conjunta que encaja con la escena (o `null` si no hay ninguna).
  ///
  /// Si se pasa [category], prioriza los diálogos de esa categoría.
  JointDialogue? pickDialogue(
    EventContext ctx, {
    EventCategory? category,
    Random? random,
  }) {
    final candidates = dialogues
        .where((dialogue) => _dialogueAccepts(dialogue, ctx))
        .where((dialogue) =>
            category == null || dialogue.categories.contains(category))
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    final rng = random ?? Random();
    final weights =
        candidates.map((dialogue) => dialogue.weight.toDouble()).toList();
    return candidates[_weightedIndex(weights, rng)];
  }

  bool _dialogueAccepts(JointDialogue dialogue, EventContext ctx) {
    final when = dialogue.conditions.timeOfDay;
    if (when.isNotEmpty && !when.contains(ctx.timeOfDay)) return false;
    final bondAtLeast = dialogue.conditions.bondAtLeast;
    if (bondAtLeast != null && ctx.stats.bond < bondAtLeast) return false;
    if (dialogue.conditions.weekendOnly && !ctx.isWeekend) return false;
    if (dialogue.conditions.weekdayOnly && ctx.isWeekend) return false;
    return true;
  }

  /// Recuerdos disponibles según hora, ánimo y conexión.
  List<OfflineRecap> pickableRecaps(EventContext ctx) => recaps
      .where((recap) => _recapAccepts(recap, ctx))
      .toList(growable: false);

  bool _recapAccepts(OfflineRecap recap, EventContext ctx) {
    final when = recap.conditions.timeOfDay;
    if (when.isNotEmpty && !when.contains(ctx.timeOfDay)) return false;
    final moodAtMost = recap.conditions.moodAtMost;
    if (moodAtMost != null && ctx.stats.moodLevel.index > moodAtMost.index) {
      return false;
    }
    final bondAtLeast = recap.conditions.bondAtLeast;
    if (bondAtLeast != null && ctx.stats.bond < bondAtLeast) return false;
    final socialAtLeast = recap.conditions.socialAtLeast;
    if (socialAtLeast != null && ctx.stats.social < socialAtLeast) return false;
    return true;
  }

  /// Resumen de lo que pasó mientras el jugador no estaba.
  ///
  /// [away] es cuánto tiempo estuvo fuera el jugador. Cuanto menos tiempo,
  /// menos recuerdos; nunca cambia más de [kOfflineTotalSoftCap] por estado.
  OfflineReport buildOfflineReport({
    required StatBlock stats,
    required Duration away,
    Random? random,
    DateTime? now,
    int maxRecaps = 3,
    Set<String> recentRecapIds = const <String>{},
  }) {
    final moment = now ?? DateTime.now();
    final rng = random ?? Random();
    final ctx = EventContext(
      timeOfDay: TimeOfDaySlot.fromDateTime(moment),
      stats: stats,
      isWeekend: moment.weekday >= DateTime.saturday,
      recentEventIds: recentRecapIds,
    );

    final awayHours = away.inMinutes ~/ 60;
    var wanted = maxRecaps;
    if (awayHours < 2) {
      wanted = 1;
    } else if (awayHours < 6) {
      wanted = min(2, maxRecaps);
    }
    wanted = max(1, min(wanted, maxRecaps));

    var available = pickableRecaps(ctx)
        .where((recap) => !recentRecapIds.contains(recap.id))
        .toList();
    if (available.isEmpty) available = pickableRecaps(ctx);
    available.shuffle(rng);
    final chosen = available.take(wanted).toList(growable: false);

    var totalMood = 0.0;
    var totalEnergy = 0.0;
    var totalSocial = 0.0;
    var totalBond = 0.0;
    for (final recap in chosen) {
      totalMood += recap.delta.mood;
      totalEnergy += recap.delta.energy;
      totalSocial += recap.delta.social;
      totalBond += recap.delta.bond;
    }
    final merged = StatDelta(
      mood: _cap(totalMood),
      energy: _cap(totalEnergy),
      social: _cap(totalSocial),
      bond: _cap(totalBond),
    );

    return OfflineReport(
      recaps: chosen,
      before: stats,
      after: stats.apply(merged),
      awayHours: awayHours,
    );
  }

  double _cap(double value) => value
      .clamp(-kOfflineTotalSoftCap, kOfflineTotalSoftCap)
      .toDouble();

  /// Catálogo completo como mapa JSON-friendly (lo consume el generador).
  Map<String, dynamic> describeCatalog() => {
        'contractVersion': kEventsContractVersion,
        'eventCount': catalog.length,
        'dialogueCount': dialogues.length,
        'offlineRecapCount': recaps.length,
        'categories': {
          for (final category in EventCategory.values)
            category.name: catalog.where((e) => e.category == category).length,
        },
        'events': catalog.map((event) => event.toJson()).toList(),
        'dialogues': dialogues.map((dialogue) => dialogue.toJson()).toList(),
        'offlineRecaps': recaps.map((recap) => recap.toJson()).toList(),
      };
}

/// Memoria corta de la casa: evita repetir y guarda las últimas escenas.
class EventJournal {
  EventJournal({this.historySize = 12});

  final int historySize;
  final List<String> _history = [];
  final List<EventCategory> _categories = [];

  List<String> get recentEventIds => List.unmodifiable(_history);
  List<EventCategory> get recentCategories => List.unmodifiable(_categories);
  int get eventsPlayed => _played;
  int _played = 0;

  /// Registra un evento jugado y devuelve el contexto actualizado.
  EventContext register(GameEvent event, EventContext ctx) {
    _played++;
    _history.add(event.id);
    while (_history.length > historySize) {
      _history.removeAt(0);
    }
    _categories.add(event.category);
    while (_categories.length > 4) {
      _categories.removeAt(0);
    }
    return ctx.copyWith(
      recentEventIds: _history.toSet(),
      recentCategories: List.unmodifiable(_categories),
      sinceLastEvent: 0,
    );
  }

  void clear() {
    _history.clear();
    _categories.clear();
    _played = 0;
  }
}
