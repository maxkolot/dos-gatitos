import 'package:dos_gatitos/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterState', () {
    test('recorta siempre a 0..100', () {
      const gatito = CharacterState(
        id: 'sebastian',
        name: 'Sebastián',
        animo: 96,
        energia: 20,
      );

      expect(gatito.conStat(StatKind.animo, 140).animo, CharacterState.max);
      expect(gatito.conStat(StatKind.animo, -50).animo, CharacterState.min);
      expect(gatito.conStat(StatKind.energia, 999).energia, CharacterState.max);
    });

    test('ignora NaN e infinidad (no rompe los clamps)', () {
      const gatito = CharacterState(
        id: 'maxito',
        name: 'Maxito',
        animo: 50,
        social: 40,
      );

      expect(gatito.conStat(StatKind.animo, double.nan).animo, 50);
      expect(gatito.conStat(StatKind.social, double.infinity).social, 40);
      expect(gatito.copyWith(animo: double.nan).animo, 50);
    });

    test('aplicar respeta el piso que se le pide', () {
      const gatito = CharacterState(
        id: 'x',
        name: 'X',
        animo: 34,
        social: 31,
        carino: 90,
      );

      final resultado = gatito.aplicar(<StatKind, double>{
        StatKind.animo: -50,
        StatKind.social: -50,
        StatKind.carino: -1,
      }, piso: 30);

      expect(resultado.animo, 30);
      expect(resultado.social, 30);
      expect(resultado.carino, 89);
    });

    test('statMasBajo y necesitaMimo sirven de pista para la UI', () {
      const gatito = CharacterState(
        id: 'x',
        name: 'X',
        animo: 80,
        energia: 75,
        carino: 20,
        social: 60,
      );

      expect(gatito.statMasBajo, StatKind.carino);
      expect(gatito.necesitaMimo, isTrue);
      expect(const CharacterState(id: 'y', name: 'Y').necesitaMimo, isFalse);
    });

    test('toJson/desdeJson hacen roundtrip', () {
      const gatito = CharacterState(
        id: 'maxito',
        name: 'Maxito',
        animo: 61.5,
        energia: 42.25,
        carino: 77,
        social: 33.5,
      );

      expect(CharacterState.desdeJson(gatito.toJson()), gatito);
      expect(gatito.todos[StatKind.carino], 77);
    });

    test('desdeJson completa lo que falta con valores sanos', () {
      final gatito = CharacterState.desdeJson(<Object?, Object?>{
        'animo': 'mucho',
        'energia': null,
        'social': 9999,
      }, idPorDefecto: 'sebastian');

      expect(gatito.id, 'sebastian');
      expect(gatito.name, 'sebastian');
      expect(gatito.animo, 70);
      expect(gatito.energia, 80);
      expect(gatito.social, CharacterState.max);
    });
  });

  group('stats y catálogo de personajes', () {
    test('los nombres en español son los pedidos', () {
      expect(StatKind.animo.labelEs, 'Ánimo');
      expect(StatKind.energia.labelEs, 'Energía');
      expect(StatKind.carino.labelEs, 'Cariño');
      expect(StatKind.social.labelEs, 'Social');
      expect(RelationshipState.labelEs, 'Conexión');
    });

    test('sólo la energía es gasto; el resto no se baja nunca', () {
      expect(StatKind.energia.esGasto, isTrue);
      expect(StatKind.animo.esGasto, isFalse);
      expect(StatKind.carino.esGasto, isFalse);
      expect(StatKind.social.esGasto, isFalse);
    });

    test('statKindPorNombre encuentra por clave de guardado', () {
      expect(statKindPorNombre('carino'), StatKind.carino);
      expect(statKindPorNombre('nope'), isNull);
      expect(statKindPorNombre(null), isNull);
    });

    test('cada stat flojo tiene una sugerencia cálida', () {
      for (final kind in StatKind.values) {
        expect(kind.sugerenciaEs, isNotEmpty);
      }
    });

    test('los dos gatitos y su pareja', () {
      expect(Characters.ids, <String>['sebastian', 'maxito']);
      expect(Characters.nombre(Characters.sebastian), 'Sebastián');
      expect(Characters.nombre(Characters.maxito), 'Maxito');
      expect(Characters.parejaDe(Characters.sebastian), Characters.maxito);
      expect(Characters.parejaDe(Characters.maxito), Characters.sebastian);
      expect(Characters.esValido('sebastian'), isTrue);
      expect(Characters.esValido('otro'), isFalse);
    });
  });

  group('RelationshipState', () {
    test('la conexión se recorta y respeta el piso de descanso', () {
      const relacion = RelationshipState(conexion: 50);

      expect(relacion.conConexion(150).conexion, RelationshipState.max);
      expect(relacion.conConexion(-10).conexion, RelationshipState.min);
      expect(
        relacion
            .conConexion(-10, piso: RelationshipState.pisoDescanso)
            .conexion,
        25,
      );
    });

    test('los momentos nunca quedan negativos y los días se cuentan', () {
      const relacion = RelationshipState(momentos: 1, desde: null);

      expect(relacion.conMomentos(-5).momentos, 0);
      expect(relacion.conMomentos(3).momentos, 4);
      expect(relacion.diasJuntos(DateTime(2026, 5, 1)), 0);

      final conFecha = RelationshipState(desde: DateTime(2026, 5, 1, 20));
      expect(conFecha.diasJuntos(DateTime(2026, 5, 11, 20)), 10);
      expect(conFecha.diasJuntos(DateTime(2026, 4, 1)), 0);
    });

    test('roundtrip de JSON', () {
      final relacion = RelationshipState(
        conexion: 63.5,
        momentos: 7,
        desde: DateTime(2026, 5, 1, 20),
      );

      final leida = RelationshipState.desdeJson(relacion.toJson());
      expect(leida, relacion);
      expect(RelationshipState.desdeJson(<Object?, Object?>{}).conexion, 50);
    });
  });

  group('TamagotchiState', () {
    final ahora = DateTime(2026, 5, 1, 20);

    test('la partida nueva trae a los dos gatitos contentos', () {
      final estado = TamagotchiState.nuevo(ahora);

      expect(estado.gatitos.length, 2);
      expect(estado.sebastian.name, 'Sebastián');
      expect(estado.maxito.name, 'Maxito');
      expect(estado.sebastian.animo, 72);
      expect(estado.maxito.social, 70);
      expect(estado.relacion.desde, ahora);
      expect(estado.vistoEn, ahora);
      expect(estado.diasJuntos(ahora.add(const Duration(days: 2))), 2);
      expect(estado.ambos.length, 2);
    });

    test('gatito() nunca explota con un id raro', () {
      final estado = TamagotchiState.nuevo(ahora);

      expect(estado.gatito('sebastian'), estado.sebastian);
      expect(estado.gatito('fantasma').id, 'fantasma');
      expect(estado.gatito('fantasma').animo, 70);
    });

    test('conGatito/conUltimaVez devuelven copias sin mutar la original', () {
      final estado = TamagotchiState.nuevo(ahora);

      final nuevo = estado
          .conGatito(estado.sebastian.conStat(StatKind.animo, 100))
          .conUltimaVez('jugar', ahora);

      expect(estado.sebastian.animo, 72);
      expect(nuevo.sebastian.animo, 100);
      expect(nuevo.ultimaVezDe('jugar'), ahora);
      expect(estado.ultimaVezDe('jugar'), isNull);
      expect(nuevo.conGatitos(nuevo.gatitos).gatitos.length, 2);
    });

    test('roundtrip completo de guardado', () {
      final estado = TamagotchiState.nuevo(ahora)
          .conUltimaVez('hablar', ahora)
          .copyWith(relacion: estado2Relacion());

      final leido = TamagotchiState.desdeJson(estado.toJson());

      expect(leido, isNotNull);
      expect(leido!.sebastian, estado.sebastian);
      expect(leido.maxito, estado.maxito);
      expect(leido.relacion, estado.relacion);
      expect(leido.ultimaVezDe('hablar'), ahora);
      expect(leido.creadoEn, ahora);
      expect(leido.version, TamagotchiState.versionActual);
    });

    test('un guardado sin fecha de creación se descarta', () {
      expect(TamagotchiState.desdeJson(null), isNull);
      expect(TamagotchiState.desdeJson('basura'), isNull);
      expect(TamagotchiState.desdeJson(<Object?, Object?>{}), isNull);
    });

    test('un guardado incompleto se completa, no se descarta', () {
      final leido = TamagotchiState.desdeJson(<Object?, Object?>{
        'creadoEn': '2026-05-01T20:00:00.000',
        'gatitos': <Object?, Object?>{
          'sebastian': <Object?, Object?>{'animo': 55},
        },
        'ultimasAcciones': <Object?, Object?>{
          'jugar': 'no es fecha',
          'hablar': '2026-05-01T21:00:00.000',
        },
      });

      expect(leido, isNotNull);
      expect(leido!.sebastian.animo, 55);
      expect(leido.sebastian.name, 'sebastian');
      expect(leido.maxito.name, 'Maxito');
      expect(leido.vistoEn, leido.creadoEn);
      expect(leido.ultimaVezDe('jugar'), isNull);
      expect(leido.ultimaVezDe('hablar'), DateTime(2026, 5, 1, 21));
    });
  });
}

/// Helper chiquito para el test de roundtrip.
RelationshipState estado2Relacion() => RelationshipState(
  conexion: 71.5,
  momentos: 4,
  desde: DateTime(2026, 4, 20),
);
