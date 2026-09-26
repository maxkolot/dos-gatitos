# Barcelona Life & Events (rol R18)

Vida cotidiana de Sebastián y Maxito: catálogo de eventos, charlas conjuntas y
recuerdos «Mientras no estabas…». **Solo contenido y lógica**: sin red, sin UI,
sin tocar el estado del juego desde afuera. Dart puro (no importa Flutter), así
que se testea y se reutiliza sin arrancar la app.

## Qué hay

| Archivo | Qué es |
| --- | --- |
| `models.dart` | Estados (`StatBlock`), cambios suaves (`StatDelta`), condiciones, evento, diálogo, recuerdo, contexto y resultados. |
| `event_catalog.dart` | **65 eventos** (`kEventCatalog`) de piso, música, vino, café, lluvia, balcón, Gràcia, Eixample, Raval, Barceloneta, Montjuïc, Sitges, metro de madrugada, supermercado de noche y disparates domésticos. |
| `dialogues.dart` | **10 charlas conjuntas** (`kJointDialogues`) donde se interrumpen (`interruptsPrevious: true`). |
| `offline_recap.dart` | **18 recuerdos** (`kOfflineRecaps`) con el prefijo `Mientras no estabas…`. |
| `event_engine.dart` | `EventEngine` (elige por peso y condiciones, aplica deltas), `EventJournal` (evita repeticiones). |
| `events.dart` | Barrel: `import 'package:dos_gatitos/features/events/events.dart';` |

## API para el integrador

```dart
final engine = EventEngine();
final journal = EventJournal();
var ctx = EventContext.fromDateTime(DateTime.now(), dayIndex: 1);

// 1) qué puede pasar ahora
final options = engine.pickableEvents(ctx);          // lista estable

// 2) elegir una escena (determinista con la misma semilla)
final event = engine.pickEvent(ctx, random: Random(42));
if (event != null) {
  // 3) texto + estados nuevos (nunca fuera de 0..100, nunca más de ±6)
  final outcome = engine.resolveEvent(event, ctx);
  // 4) charla conjunta que encaja con la escena
  final chat = engine.pickDialogue(ctx, category: event.category);
  // 5) guardar para no repetir y actualizar el contexto
  ctx = journal.register(event, ctx).copyWith(stats: outcome.after);
}

// 6) al volver el jugador
final report = engine.buildOfflineReport(
  stats: ctx.stats,
  away: const Duration(hours: 9),
  now: DateTime.now(),
);
report.lines;   // ["Mientras no estabas… …", …]
report.after;   // StatBlock nuevo (cambio total acotado a ±9)
```

Reglas del contrato:

* El motor **no** muta nada por su cuenta: `resolveEvent` devuelve un `StatBlock`
  nuevo y el integrador decide cuándo guardarlo.
* `EventContext` lleva la hora (`TimeOfDaySlot`), el ánimo, la conexión, el día
  de partida, si es finde y lo que ya salió (`recentEventIds`/`recentCategories`).
* Las condiciones vacías significan «no importa». Algunas escenas exigen
  franja horaria (p. ej. metro de madrugada), ánimo bajo (consuelo), ánimo alto
  (festejo), conexión alta (Sitges, silencio cómodo) o finde (salidas).

## API para el generador

* `dart run tool/export_events.dart` escribe `assets/content/events.json`
  (registrado en `pubspec.yaml`) con `contractVersion`, `eventCount`,
  `categories`, y los arrays `events`, `dialogues`, `offlineRecaps`.
* En runtime lo mismo: `engine.describeCatalog()` devuelve ese mapa.
* `kEventsContractVersion` sube cuando cambia la forma de los datos.
* Los eventos nuevos se añaden solo a `kEventCatalog` con `id` único, texto
  español, `delta` dentro de ±6 y `weight` 1–10 (1–3 = raro).
* Un test compara el JSON con el catálogo en Dart: si editas contenido,
  volvé a correr el export.

## Tests

```bash
flutter analyze && flutter test
```

Cubren: ≥40 eventos y cobertura de todas las categorías, salidas raras,
dependencia de hora/ánimo/conexión, copia en español sin cirílico/inglés/tono
feo, ruso latinizado de Sebastián entre el 3% y el 12% de sus líneas (Maxito
nunca), deltas suaves y estados dentro de 0..100, determinismo del motor,
enfriamiento, interrupciones de las charlas, ≥15 recuerdos offline con resumen
acotado y la sincronía de `assets/content/events.json`.

## Fuera de alcance (a propósito)

Sin red, sin DeepSeek, sin UI, sin mutar `game state` desde afuera y sin tocar
`lib/features/features.dart` (esa lista es de componentes Flame).
