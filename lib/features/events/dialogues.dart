/// Charlas conjuntas: Sebastián y Maxito hablando al mismo tiempo.
///
/// En varias líneas uno le pisa la frase al otro (`interruptsPrevious: true`),
/// porque en esta casa nadie espera su turno para decir algo importante.
library;

import 'models.dart';

/// Diálogos conjuntos del catálogo.
const List<JointDialogue> kJointDialogues = [
  JointDialogue(
    id: 'dlg_que_cocinamos',
    spark: 'Se hace tarde y la pregunta de siempre: ¿qué cocinamos?',
    weight: 8,
    categories: [EventCategory.piso, EventCategory.supermercado],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Podemos hacer pasta con lo que hay en la heladera.'),
      DialogueLine(LineSpeaker.sebastian, 'Lo que hay es medio tomate y un limón.'),
      DialogueLine(LineSpeaker.maxito, 'Entonces pasta con limón. Es gourmet.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Es un limón con agua caliente, pero te sigo.'),
      DialogueLine(LineSpeaker.maxito, 'Y añadimos queso. Ahora sí es gourmet de verdad.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_planes_finde',
    spark: 'Sábado a la mañana y dos planes distintos en la mesa.',
    weight: 7,
    categories: [
      EventCategory.gracia,
      EventCategory.barceloneta,
      EventCategory.sitges,
    ],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Yo digo Gràcia: vermut, plaza, pocas cuadras.'),
      DialogueLine(LineSpeaker.maxito, 'Y yo digo playa. Mar, arena, chiringuito.'),
      DialogueLine(LineSpeaker.sebastian, 'Mar en octubre. Vas a temblar como un flan.'),
      DialogueLine(LineSpeaker.maxito, 'Temblamos juntos, entonces. Vamos a la playa.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Vamos a la playa, pero después vermut para compensar.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_vasos_balcon',
    spark: 'Uno quiere llevar la botella al balcón, el otro no quiere más visitas de la vecina.',
    weight: 6,
    categories: [EventCategory.vino, EventCategory.balcon],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Llevamos el vino afuera y miramos la calle.'),
      DialogueLine(LineSpeaker.sebastian, 'La última vez la vecina golpeó la escoba a la una.'),
      DialogueLine(LineSpeaker.maxito, 'A la una no, a las doce y media.'),
      DialogueLine(LineSpeaker.sebastian, 'Eso es mucho peor y vos lo sabés.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.maxito, 'Vasos de vidrio de la cocina. Si se cae, se cae juntos.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_cafe_manana',
    spark: 'Siete y media de la mañana en la cocina, con muy pocas palabras disponibles.',
    weight: 7,
    categories: [EventCategory.cafe, EventCategory.piso],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Te cuento lo que soñé: había un tren y un gato con sombrero.'),
      DialogueLine(LineSpeaker.sebastian, 'Mhm.'),
      DialogueLine(LineSpeaker.maxito, 'Y el gato te llevaba a vos, no a mí, y eso es importante...',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Café. Después el gato, el tren y la denuncia.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_lluvia_paraguas',
    spark: 'Llueve y hay un solo paraguas en el paragüero.',
    weight: 6,
    categories: [EventCategory.lluvia, EventCategory.balcon],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Vos sos más alto, llevá vos el paraguas.'),
      DialogueLine(LineSpeaker.sebastian, 'Yo soy más alto, así que vos vas a ir echado encima.'),
      DialogueLine(LineSpeaker.maxito, 'No es lo mismo, entonces el paraguas es mío.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Es lo mismo y los dos nos vamos a mojar igual. Caminá.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_playlist',
    spark: 'La playlist compartida vuelve a ser un campo de batalla sin heridos.',
    weight: 6,
    categories: [EventCategory.musica, EventCategory.piso],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Hay que sacar la canción que repetiste todo marzo.'),
      DialogueLine(LineSpeaker.maxito, 'No repetí nada. Esa canción es buena.'),
      DialogueLine(LineSpeaker.sebastian, 'La pusiste seis veces en una cena. Tengo pruebas.'),
      DialogueLine(LineSpeaker.maxito, 'Las pruebas las inventaste vos.', interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Dos canciones cada uno. Una que quieras y una de vergüenza.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_vino_cata',
    spark: 'Sebastián quiere una cata seria y Maxito ya está mirando la etiqueta al revés.',
    weight: 5,
    categories: [EventCategory.vino],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Primero lo olemos. Sin apuro. Como la gente.'),
      DialogueLine(LineSpeaker.maxito, 'Huele a vino. Confirmado. Siguiente paso.'),
      DialogueLine(LineSpeaker.sebastian, 'No es un examen, es un placer.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.maxito, 'Mi placer es tomarlo con fideos a las nueve. Brindis.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_metro_vuelta',
    spark: 'Último metro, los dos cansados y las llaves perdidas en la mochila.',
    weight: 5,
    categories: [EventCategory.metro, EventCategory.raval],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Yo tengo las llaves en algún lado, juraría que sí.'),
      DialogueLine(LineSpeaker.sebastian, 'Juraría es una palabra grande para las dos de la mañana.'),
      DialogueLine(LineSpeaker.maxito, 'Encontradas. Estaban en el bolsillo más chico.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Sentate y dormí un parada. Te despierto en casa.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_super_presupuesto',
    spark: 'Carrito en mano, la cuenta mental de uno contra el entusiasmo del otro.',
    weight: 5,
    categories: [EventCategory.supermercado],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Esta semana sin extras. Solo la lista.'),
      DialogueLine(LineSpeaker.maxito, 'Perfecto. Y estas galletas con dinosaurios son de la lista.'),
      DialogueLine(LineSpeaker.sebastian, 'No figuran en la lista ni en ninguna lista humana.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.maxito, 'Figuran en la lista emocional. Y esa la escribimos los dos.'),
    ],
  ),
  JointDialogue(
    id: 'dlg_sitges_tren',
    spark: 'Ventanilla del tren de cercanías, mar a la derecha.',
    weight: 4,
    categories: [EventCategory.sitges, EventCategory.eixample],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Decime otra vez por qué no hacemos esto todos los fines de semana.'),
      DialogueLine(LineSpeaker.sebastian, 'Porque el sábado uno de los dos trabaja y siempre es vos.'),
      DialogueLine(LineSpeaker.maxito, 'Hay tests el sábado, no es culpa mía.',
          interruptsPrevious: true),
      DialogueLine(LineSpeaker.sebastian, 'Nunca es tu culpa y siempre es el tren. Mirá el mar y no digas nada un rato.'),
    ],
  ),
];

/// Diálogos que encajan mejor con una categoría determinada.
List<JointDialogue> dialoguesFor(EventCategory category) => kJointDialogues
    .where((dialogue) => dialogue.categories.contains(category))
    .toList(growable: false);

Map<String, JointDialogue> get kDialoguesById =>
    {for (final dialogue in kJointDialogues) dialogue.id: dialogue};
