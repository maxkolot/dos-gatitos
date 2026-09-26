// Exporta el catálogo de eventos a assets/content/events.json.
//
// Lo usan el generador de contenido y el integrador (además de los tests de
// integridad, que comparan el JSON con el catálogo en Dart).
//
//   dart run tool/export_events.dart
import 'dart:convert';
import 'dart:io';

import 'package:dos_gatitos/features/events/events.dart';

void main() {
  final engine = EventEngine();
  final catalog = engine.describeCatalog();
  final file = File('assets/content/events.json');
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(catalog)}\n');
  stdout.writeln(
    'events.json: ${catalog['eventCount']} eventos, '
    '${catalog['dialogueCount']} diálogos, '
    '${catalog['offlineRecapCount']} recuerdos offline '
    '(contrato v$kEventsContractVersion)',
  );
}
