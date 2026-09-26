/// Modelos de la vida cotidiana de Sebastián y Maxito en Barcelona.
///
/// Todo lo que ve el jugador está en español. Esta biblioteca es Dart puro:
/// no importa Flutter, no hace red y no toca disco, así que el motor de
/// eventos se puede probar (y reutilizar) sin arrancar la app.
///
/// Autor de la zona: rol «06 · Barcelona Life & Events» (R18).
library;

/// Franja del día que usan las condiciones de los eventos.
enum TimeOfDaySlot {
  madrugada('Madrugada'),
  manana('Mañana'),
  mediodia('Mediodía'),
  tarde('Tarde'),
  noche('Noche');

  const TimeOfDaySlot(this.label);

  /// Nombre visible en español.
  final String label;

  /// Franja a la que pertenece una hora del reloj (0–23).
  static TimeOfDaySlot fromHour(int hour) {
    final h = hour % 24;
    if (h >= 1 && h <= 5) return TimeOfDaySlot.madrugada;
    if (h >= 6 && h <= 11) return TimeOfDaySlot.manana;
    if (h >= 12 && h <= 14) return TimeOfDaySlot.mediodia;
    if (h >= 15 && h <= 19) return TimeOfDaySlot.tarde;
    return TimeOfDaySlot.noche; // 20–23 y 0
  }

  static TimeOfDaySlot fromDateTime(DateTime moment) =>
      fromHour(moment.hour);
}

/// Tipo de vida cotidiana al que pertenece un evento.
enum EventCategory {
  piso('Piso'),
  musica('Música'),
  vino('Vino'),
  cafe('Café'),
  lluvia('Lluvia'),
  balcon('Balcón'),
  gracia('Gràcia'),
  eixample('Eixample'),
  raval('Raval'),
  barceloneta('Barceloneta'),
  montjuic('Montjuïc'),
  sitges('Sitges'),
  metro('Metro'),
  supermercado('Supermercado'),
  rutina('Rutina'),
  mimo('Mimo');

  const EventCategory(this.label);

  /// Nombre visible en español.
  final String label;

  /// Salidas de Barcelona (y alrededores) que aparecen como plan raro.
  bool get isOuting => const {
        EventCategory.gracia,
        EventCategory.eixample,
        EventCategory.raval,
        EventCategory.barceloneta,
        EventCategory.montjuic,
        EventCategory.sitges,
      }.contains(this);
}

/// Quién dice una línea.
enum LineSpeaker {
  sebastian('Sebastián'),
  maxito('Maxito'),
  ambiente('—');

  const LineSpeaker(this.label);

  /// Nombre visible en español.
  final String label;
}

/// Nivel de ánimo derivado de [StatBlock.mood].
enum MoodLevel {
  bajo('bajo'),
  normal('normal'),
  alto('alto');

  const MoodLevel(this.label);
  final String label;

  static MoodLevel fromMood(double mood) {
    if (mood < 35) return MoodLevel.bajo;
    if (mood > 72) return MoodLevel.alto;
    return MoodLevel.normal;
  }
}

/// Cuánta conexión hay entre los dos gatos.
enum ConnectionLevel {
  distante('distante'),
  tibia('tibia'),
  cercana('cercana'),
  fusionados('fusionados');

  const ConnectionLevel(this.label);
  final String label;

  static ConnectionLevel fromBond(double bond) {
    if (bond < 30) return ConnectionLevel.distante;
    if (bond < 55) return ConnectionLevel.tibia;
    if (bond < 80) return ConnectionLevel.cercana;
    return ConnectionLevel.fusionados;
  }
}

/// Cambio suave de los cuatro estados de la pareja.
///
/// Los valores vivos de la casa están siempre entre 0 y 100 y ningún evento
/// mueve más de [maxStep] puntos: el juego acompaña, no castiga.
class StatDelta {
  const StatDelta({
    this.mood = 0,
    this.energy = 0,
    this.social = 0,
    this.bond = 0,
  });

  final double mood;
  final double energy;
  final double social;
  final double bond;

  /// Ningún evento suelto puede mover más de esto.
  static const double maxStep = 6;

  static const StatDelta zero = StatDelta();

  bool get isZero => mood == 0 && energy == 0 && social == 0 && bond == 0;

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'energy': energy,
        'social': social,
        'bond': bond,
      };

  @override
  String toString() =>
      'StatDelta(mood: $mood, energy: $energy, social: $social, bond: $bond)';
}

/// Estado de la pareja: ánimo, energía, ganas de socializar y conexión.
class StatBlock {
  const StatBlock({
    this.mood = 60,
    this.energy = 60,
    this.social = 60,
    this.bond = 60,
  });

  final double mood;
  final double energy;
  final double social;
  final double bond;

  static const double min = 0;
  static const double max = 100;

  MoodLevel get moodLevel => MoodLevel.fromMood(mood);
  ConnectionLevel get connectionLevel => ConnectionLevel.fromBond(bond);

  static double _clamp(double value) => value.clamp(min, max).toDouble();

  /// Aplica un cambio suave y devuelve el estado resultante (siempre 0–100).
  StatBlock apply(StatDelta delta) => StatBlock(
        mood: _clamp(mood + delta.mood),
        energy: _clamp(energy + delta.energy),
        social: _clamp(social + delta.social),
        bond: _clamp(bond + delta.bond),
      );

  StatBlock copyWith({
    double? mood,
    double? energy,
    double? social,
    double? bond,
  }) =>
      StatBlock(
        mood: _clamp(mood ?? this.mood),
        energy: _clamp(energy ?? this.energy),
        social: _clamp(social ?? this.social),
        bond: _clamp(bond ?? this.bond),
      );

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'energy': energy,
        'social': social,
        'bond': bond,
      };

  @override
  String toString() =>
      'StatBlock(mood: $mood, energy: $energy, social: $social, bond: $bond)';
}

/// Reglas que deciden si un evento puede aparecer.
///
/// Cualquier campo en `null` o lista vacía significa «no importa».
class EventConditions {
  const EventConditions({
    this.timeOfDay = const [],
    this.moodAtLeast,
    this.moodAtMost,
    this.energyAtMost,
    this.energyAtLeast,
    this.bondAtLeast,
    this.socialAtLeast,
    this.weekdayOnly = false,
    this.weekendOnly = false,
    this.minDayIndex = 0,
  });

  /// Franjas del día en las que puede salir. Vacío = a cualquier hora.
  final List<TimeOfDaySlot> timeOfDay;
  final MoodLevel? moodAtLeast;
  final MoodLevel? moodAtMost;
  final double? energyAtMost;
  final double? energyAtLeast;
  final double? bondAtLeast;
  final double? socialAtLeast;
  final bool weekdayOnly;
  final bool weekendOnly;

  /// No aparece antes de este día de partida (para que la vida se abra poco a poco).
  final int minDayIndex;

  static const EventConditions none = EventConditions();

  Map<String, dynamic> toJson() => {
        if (timeOfDay.isNotEmpty)
          'timeOfDay': timeOfDay.map((s) => s.name).toList(),
        if (moodAtLeast != null) 'moodAtLeast': moodAtLeast!.name,
        if (moodAtMost != null) 'moodAtMost': moodAtMost!.name,
        if (energyAtMost != null) 'energyAtMost': energyAtMost,
        if (energyAtLeast != null) 'energyAtLeast': energyAtLeast,
        if (bondAtLeast != null) 'bondAtLeast': bondAtLeast,
        if (socialAtLeast != null) 'socialAtLeast': socialAtLeast,
        if (weekdayOnly) 'weekdayOnly': true,
        if (weekendOnly) 'weekendOnly': true,
        if (minDayIndex > 0) 'minDayIndex': minDayIndex,
      };
}

/// Una línea de diálogo de un evento o de una charla conjunta.
class DialogueLine {
  const DialogueLine(
    this.speaker,
    this.text, {
    this.interruptsPrevious = false,
  });

  final LineSpeaker speaker;

  /// Texto en español, listo para mostrar.
  final String text;

  /// `true` cuando la línea pisa la anterior (se interrumpen, como en casa).
  final bool interruptsPrevious;

  Map<String, dynamic> toJson() => {
        'speaker': speaker.name,
        'text': text,
        if (interruptsPrevious) 'interruptsPrevious': true,
      };
}

/// Un momento de vida en Barcelona (el corazón del catálogo).
class GameEvent {
  const GameEvent({
    required this.id,
    required this.category,
    required this.title,
    required this.scene,
    required this.delta,
    this.lines = const [],
    this.conditions = EventConditions.none,
    this.weight = 5,
    this.tags = const [],
    this.cooldown = 5,
  });

  /// Identificador estable (lo usa el generador y el guardado local).
  final String id;
  final EventCategory category;

  /// Título corto para el registro de la casa.
  final String title;

  /// Lo que pasa, en una o dos frases.
  final String scene;

  /// Cambio suave de estados.
  final StatDelta delta;

  /// Diálogo que acompaña la escena.
  final List<DialogueLine> lines;

  /// Cuándo puede aparecer.
  final EventConditions conditions;

  /// Peso relativo (1 = raro, 10 = cotidiano).
  final int weight;

  /// Etiquetas libres para el generador (p. ej. `salida`, `noche`, `comedia`).
  final List<String> tags;

  /// Cuántos eventos tienen que pasar antes de que se repita.
  final int cooldown;

  bool get isOuting => category.isOuting;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'categoryLabel': category.label,
        'title': title,
        'scene': scene,
        'weight': weight,
        'cooldown': cooldown,
        'tags': tags,
        'conditions': conditions.toJson(),
        'delta': delta.toJson(),
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  @override
  String toString() => 'GameEvent($id)';
}

/// Charla conjunta: los dos hablan a la vez y se pisan las frases.
class JointDialogue {
  const JointDialogue({
    required this.id,
    required this.spark,
    required this.lines,
    this.categories = const [],
    this.conditions = EventConditions.none,
    this.weight = 5,
  });

  final String id;

  /// Qué la dispara (una frase de situación en español).
  final String spark;

  final List<DialogueLine> lines;

  /// Categorías de evento con las que encaja bien.
  final List<EventCategory> categories;

  final EventConditions conditions;
  final int weight;

  bool get hasInterruption =>
      lines.any((line) => line.interruptsPrevious) && lines.length >= 3;

  Map<String, dynamic> toJson() => {
        'id': id,
        'spark': spark,
        'weight': weight,
        'categories': categories.map((c) => c.name).toList(),
        'conditions': conditions.toJson(),
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

/// Recuerdo breve de lo que pasó mientras el jugador no estaba.
class OfflineRecap {
  const OfflineRecap({
    required this.id,
    required this.text,
    this.delta = StatDelta.zero,
    this.tags = const [],
    this.weight = 5,
    this.conditions = EventConditions.none,
  });

  /// Cada recuerdo se muestra encabezado por este prefijo.
  static const String prefix = 'Mientras no estabas…';

  final String id;

  /// Texto sin el prefijo (en español).
  final String text;
  final StatDelta delta;
  final List<String> tags;
  final int weight;
  final EventConditions conditions;

  /// Texto completo tal como se muestra al jugador.
  String get display => '$prefix $text';

  Map<String, dynamic> toJson() => {
        'id': id,
        'prefix': prefix,
        'text': text,
        'display': display,
        'weight': weight,
        'tags': tags,
        'conditions': conditions.toJson(),
        'delta': delta.toJson(),
      };
}

/// Todo lo que el motor necesita saber del momento actual.
class EventContext {
  const EventContext({
    required this.timeOfDay,
    this.stats = const StatBlock(),
    this.dayIndex = 0,
    this.isWeekend = false,
    this.recentEventIds = const <String>{},
    this.recentCategories = const <EventCategory>[],
    this.sinceLastEvent = 0,
  });

  final TimeOfDaySlot timeOfDay;
  final StatBlock stats;

  /// Día de partida (0 = primer día).
  final int dayIndex;

  /// Sábado o domingo.
  final bool isWeekend;

  /// Eventos que ya salieron hace poco (para no repetir).
  final Set<String> recentEventIds;

  /// Categorías recientes, para alternar piso y calle.
  final List<EventCategory> recentCategories;

  /// Cuántos eventos pasaron desde el último (0 = acaba de pasar uno).
  final int sinceLastEvent;

  EventContext copyWith({
    TimeOfDaySlot? timeOfDay,
    StatBlock? stats,
    int? dayIndex,
    bool? isWeekend,
    Set<String>? recentEventIds,
    List<EventCategory>? recentCategories,
    int? sinceLastEvent,
  }) =>
      EventContext(
        timeOfDay: timeOfDay ?? this.timeOfDay,
        stats: stats ?? this.stats,
        dayIndex: dayIndex ?? this.dayIndex,
        isWeekend: isWeekend ?? this.isWeekend,
        recentEventIds: recentEventIds ?? this.recentEventIds,
        recentCategories: recentCategories ?? this.recentCategories,
        sinceLastEvent: sinceLastEvent ?? this.sinceLastEvent,
      );

  /// Construye el contexto desde un reloj real (lo usa la app y el guardado).
  static EventContext fromDateTime(
    DateTime moment, {
    StatBlock stats = const StatBlock(),
    int dayIndex = 0,
    Set<String> recentEventIds = const <String>{},
    List<EventCategory> recentCategories = const <EventCategory>[],
    int sinceLastEvent = 0,
  }) =>
      EventContext(
        timeOfDay: TimeOfDaySlot.fromDateTime(moment),
        stats: stats,
        dayIndex: dayIndex,
        isWeekend: moment.weekday >= DateTime.saturday,
        recentEventIds: recentEventIds,
        recentCategories: recentCategories,
        sinceLastEvent: sinceLastEvent,
      );
}

/// Resultado de un evento: texto listo para mostrar y estados nuevos.
class EventOutcome {
  const EventOutcome({
    required this.event,
    required this.before,
    required this.after,
    required this.lines,
  });

  final GameEvent event;
  final StatBlock before;
  final StatBlock after;
  final List<DialogueLine> lines;

  StatDelta get applied => StatDelta(
        mood: after.mood - before.mood,
        energy: after.energy - before.energy,
        social: after.social - before.social,
        bond: after.bond - before.bond,
      );

  @override
  String toString() => 'EventOutcome(${event.id}, $applied)';
}

/// Lo que pasó mientras el jugador no estaba.
class OfflineReport {
  const OfflineReport({
    required this.recaps,
    required this.before,
    required this.after,
    this.awayHours = 0,
  });

  final List<OfflineRecap> recaps;
  final StatBlock before;
  final StatBlock after;
  final int awayHours;

  StatDelta get totalDelta => StatDelta(
        mood: after.mood - before.mood,
        energy: after.energy - before.energy,
        social: after.social - before.social,
        bond: after.bond - before.bond,
      );

  /// Frases «Mientras no estabas…» listas para el resumen de bienvenida.
  List<String> get lines => recaps.map((r) => r.display).toList();

  @override
  String toString() => 'OfflineReport(${recaps.length} recuerdos)';
}
