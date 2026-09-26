/// Catálogo de la vida de Sebastián y Maxito en Barcelona.
///
/// Mínimo 40 eventos; hoy hay más de 45 repartidos entre piso, música, vino,
/// café, lluvia, balcón, salidas raras (Gràcia, Eixample, Raval, Barceloneta,
/// Montjuïc, Sitges), metro después de la fiesta, supermercado de noche y
/// disparates domésticos. Cada evento mueve los estados como máximo ±6 puntos.
///
/// Todas las condiciones se evalúan contra `EventContext`
/// (hora del día + ánimo + conexión + día de partida).
library;

import 'models.dart';

/// El catálogo completo, en orden estable (el motor lo usa con semilla).
const List<GameEvent> kEventCatalog = [
  // ───────────────────────────── PISO ─────────────────────────────
  GameEvent(
    id: 'piso_desayuno_tarde',
    category: EventCategory.piso,
    title: 'Desayuno a las tres de la tarde',
    scene:
        'Nadie tiene hambre a la hora que corresponde. Sebastián prepara tostadas con tomate y Maxito las mira como si fueran un milagro recién bajado del cielo.',
    weight: 7,
    tags: ['piso', 'comida', 'cocina'],
    lines: [
      DialogueLine(LineSpeaker.sebastian,
          'En Argentina esto sería una merienda, pero acepto tu calendario.'),
      DialogueLine(LineSpeaker.maxito,
          'Es desayuno si todavía no nos dormimos. Regla de la casa.'),
    ],
    delta: StatDelta(mood: 3, energy: 4, social: 2, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
    ),
  ),
  GameEvent(
    id: 'piso_nevera_conspiracion',
    category: EventCategory.piso,
    title: 'Los dos mirando la nevera',
    scene:
        'Abren la nevera al mismo tiempo, la miran en silencio y ninguno dice nada. Es un ritual viejo que ya tiene su propio ritmo.',
    weight: 6,
    tags: ['piso', 'comedia', 'cocina'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Hay queso. Hay aceitunas. Hay... futuro.'),
      DialogueLine(LineSpeaker.sebastian, 'Cerrá la puerta, que el frío se escapa.',
          interruptsPrevious: true),
    ],
    delta: StatDelta(mood: 2, energy: 3, bond: 1),
  ),
  GameEvent(
    id: 'piso_guerra_sofa',
    category: EventCategory.piso,
    title: 'Guerra silenciosa por el lado del sofá',
    scene:
        'El lado del sofá con la lámpara al lado es el mejor. Los dos lo saben. Ninguno lo va a decir en voz alta.',
    weight: 6,
    tags: ['piso', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Yo me senté primero, es un hecho objetivo.'),
      DialogueLine(LineSpeaker.sebastian,
          'Yo llegué primero a la vida, así que en realidad es mi sofá.'),
      DialogueLine(LineSpeaker.ambiente,
          'Terminan los dos en el mismo lado, uno encima del otro.'),
    ],
    delta: StatDelta(mood: 3, social: 2, bond: 3),
  ),
  GameEvent(
    id: 'piso_planta_montserrat',
    category: EventCategory.piso,
    title: 'La planta que ahora es de los dos',
    scene:
        'Compraron una suculenta para el balcón y Maxito la bautizó Montserrat, aunque no se parece a ninguna montaña.',
    weight: 5,
    tags: ['piso', 'comedia', 'plantas'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Montserrat creció dos milímetros. Estoy orgulloso.'),
      DialogueLine(LineSpeaker.sebastian,
          'La regaste con la misma agua del mate. No sé si eso cuenta como cariño.'),
    ],
    delta: StatDelta(mood: 2, energy: 1, bond: 2),
  ),
  GameEvent(
    id: 'piso_cargador_viajero',
    category: EventCategory.piso,
    title: 'El cargador que viaja solo',
    scene:
        'El cargador del teléfono aparece en la cocina, después en el baño, después dentro de un zapato. Nadie lo movió, según los dos.',
    weight: 5,
    tags: ['piso', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Privet, cargador. Otra vez en la cocina.'),
      DialogueLine(LineSpeaker.maxito,
          'No me mirés así, el enchufe de la cocina es el único que carga rápido.'),
    ],
    delta: StatDelta(mood: 2, social: 1, bond: 1),
  ),
  GameEvent(
    id: 'piso_siesta_sofa',
    category: EventCategory.piso,
    title: 'Siesta compartida sin acordarla',
    scene:
        'Uno se recuesta «un minuto» y el otro se sienta al lado a leer. Diez minutos después están los dos dormidos con el libro abierto.',
    weight: 6,
    tags: ['piso', 'descanso'],
    lines: [
      DialogueLine(LineSpeaker.ambiente,
          'El libro queda abierto en la página 42, que ya nadie recuerda.'),
    ],
    delta: StatDelta(mood: 3, energy: 5, social: -1, bond: 2),
    conditions: EventConditions(energyAtMost: 45),
  ),
  GameEvent(
    id: 'piso_abrazo_sin_palabras',
    category: EventCategory.mimo,
    title: 'Un abrazo sin explicaciones',
    scene:
        'Hoy el día viene gris y no hace falta preguntar nada. Sebastián abre los brazos y Maxito entra sin decir una palabra.',
    weight: 8,
    tags: ['piso', 'consuelo', 'mimo'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'No hace falta que expliques nada.'),
      DialogueLine(LineSpeaker.maxito, 'Ya sé. Solo quedate un rato más.'),
    ],
    delta: StatDelta(mood: 5, energy: 2, social: 4, bond: 4),
    conditions: EventConditions(moodAtMost: MoodLevel.bajo),
  ),
  GameEvent(
    id: 'piso_dia_gris',
    category: EventCategory.piso,
    title: 'Un día de esos',
    scene:
        'Sin motivo claro, el ánimo está bajo. La casa responde con mantas, sopa de sobre y una serie que ya vieron dos veces.',
    weight: 5,
    tags: ['piso', 'consuelo'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Hoy no hacemos nada importante, ¿sí?'),
      DialogueLine(LineSpeaker.sebastian, 'Hoy es nuestro plan: no hacer nada. Davai.'),
    ],
    delta: StatDelta(mood: 3, energy: 3, social: 2, bond: 2),
    conditions: EventConditions(moodAtMost: MoodLevel.bajo),
  ),
  GameEvent(
    id: 'piso_festejo_minimo',
    category: EventCategory.piso,
    title: 'Festejo por algo mínimo',
    scene:
        'Sebastián terminó una lista de cosas aburridas y Maxito insiste en celebrarlo con la botella que guardaban «para algo importante».',
    weight: 6,
    tags: ['piso', 'festejo'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Es un gran día porque yo digo que es un gran día.'),
      DialogueLine(LineSpeaker.sebastian, 'Spasibo. Nadie celebra así un lunes.'),
    ],
    delta: StatDelta(mood: 4, energy: 2, social: 3, bond: 3),
    conditions: EventConditions(moodAtLeast: MoodLevel.alto),
  ),

  // ───────────────────────────── MÚSICA ─────────────────────────────
  GameEvent(
    id: 'musica_vinilos_madrugada',
    category: EventCategory.musica,
    title: 'Vinilos a las dos de la mañana',
    scene:
        'El volumen bajísimo, la aguja cayendo despacio, los dos en el suelo como si tuvieran veinte años.',
    weight: 6,
    tags: ['musica', 'noche'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Este disco hay que escucharlo entero, sin saltar.'),
      DialogueLine(LineSpeaker.maxito, 'Escucho entero, pero el lado B lo pongo yo.'),
    ],
    delta: StatDelta(mood: 4, energy: -2, social: 3, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.madrugada],
    ),
  ),
  GameEvent(
    id: 'musica_playlist_disputa',
    category: EventCategory.musica,
    title: 'La playlist compartida',
    scene:
        'La playlist conjunta tiene dos facciones y una canción que aparece tres veces. Nadie asume la culpa.',
    weight: 7,
    tags: ['musica', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Hay bossa nova tres veces. Y una es a las 7 de la mañana.'),
      DialogueLine(LineSpeaker.maxito, 'Y hay un tango lento en el medio. ¿Quién lo puso?'),
      DialogueLine(LineSpeaker.sebastian, 'No me acuerdo. Siguiente pregunta.',
          interruptsPrevious: true),
    ],
    delta: StatDelta(mood: 3, social: 2, bond: 1),
  ),
  GameEvent(
    id: 'musica_baile_cocina',
    category: EventCategory.musica,
    title: 'Baile en la cocina',
    scene:
        'Suena una canción que no es romántica, pero igual bailan entre la mesada y la heladera, esquivando la sartén.',
    weight: 6,
    tags: ['musica', 'amor'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Un paso más y tiramos la sartén.'),
      DialogueLine(LineSpeaker.sebastian, 'Tirá la sartén, total la compramos en el chino.'),
    ],
    delta: StatDelta(mood: 5, energy: -1, social: 3, bond: 4),
    conditions: EventConditions(moodAtLeast: MoodLevel.normal),
  ),
  GameEvent(
    id: 'musica_vecina_escoba',
    category: EventCategory.musica,
    title: 'La escoba de la vecina',
    scene:
        'La vecina del cuarto golpea el techo con la escoba. Cinco minutos después manda un mensaje con un corazón y una carita durmiendo.',
    weight: 5,
    tags: ['musica', 'comedia', 'vecinos'],
    lines: [
      DialogueLine(LineSpeaker.maxito, '¿Bajamos el volumen o subimos el corazón?'),
      DialogueLine(LineSpeaker.sebastian, 'Bajá el volumen y mandale una tortilla mañana.'),
    ],
    delta: StatDelta(mood: 2, social: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.madrugada],
    ),
  ),
  GameEvent(
    id: 'musica_ukelele_dos_acordes',
    category: EventCategory.musica,
    title: 'El ukelele de dos acordes',
    scene:
        'Maxito encontró el ukelele en el fondo del armario y tiene dos acordes y mucha confianza.',
    weight: 5,
    tags: ['musica', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'No está desafinado, está con carácter.'),
      DialogueLine(LineSpeaker.sebastian, 'Blyat, me encanta y me duele al mismo tiempo.'),
    ],
    delta: StatDelta(mood: 3, social: 1, bond: 1),
  ),
  GameEvent(
    id: 'musica_canción_que_era_nuestra',
    category: EventCategory.musica,
    title: 'La canción que era de ustedes',
    scene:
        'Suena sin aviso la canción del primer verano y los dos se quedan quietos, cada uno en su recuerdo, sonriendo al mismo tiempo.',
    weight: 4,
    tags: ['musica', 'amor', 'memoria'],
    lines: [
      DialogueLine(LineSpeaker.ambiente,
          'Ninguno la canta. Igual los dos la están cantando.'),
    ],
    delta: StatDelta(mood: 4, social: 2, bond: 5),
    conditions: EventConditions(bondAtLeast: 55),
  ),

  // ───────────────────────────── VINO ─────────────────────────────
  GameEvent(
    id: 'vino_vermut_domingo',
    category: EventCategory.vino,
    title: 'Vermut de domingo',
    scene:
        'Un vermut largo, aceitunas en un plato chiquito y la conversación que se estira sin llegar a ningún lado.',
    weight: 6,
    tags: ['vino', 'finde'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'El vermut es una hora. Pasada esa hora, es otra cosa.'),
      DialogueLine(LineSpeaker.maxito, 'Vamos por la segunda hora entonces.'),
    ],
    delta: StatDelta(mood: 4, energy: 1, social: 4, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
      weekendOnly: true,
    ),
  ),
  GameEvent(
    id: 'vino_dos_copas_balcon',
    category: EventCategory.vino,
    title: 'Dos copas en el balcón',
    scene:
        'Vino barato, sillas plegables y la calle de abajo haciendo su ruido de siempre.',
    weight: 7,
    tags: ['vino', 'balcon'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Brindo por... no sé, elegí vos.'),
      DialogueLine(LineSpeaker.sebastian, 'Brindo porque estás acá y no tengo que elegir más nada.'),
    ],
    delta: StatDelta(mood: 4, social: 3, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
    ),
  ),
  GameEvent(
    id: 'vino_cata_supermercado',
    category: EventCategory.vino,
    title: 'Cata muy seria de un vino de cuatro euros',
    scene:
        'Hoy se ponen solemnes: huelen la copa, la giran, dicen cosas sobre el bosque y el mineral.',
    weight: 5,
    tags: ['vino', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Notas de frutos rojos y de presupuesto ajustado.'),
      DialogueLine(LineSpeaker.maxito, 'Yo siento ciruela. Y ganas de otra empanada.'),
    ],
    delta: StatDelta(mood: 4, social: 2, bond: 2),
  ),
  GameEvent(
    id: 'vino_copa_alfombra',
    category: EventCategory.vino,
    title: 'La copa que encontró la alfombra',
    scene:
        'Un codo, un gesto, y el vino rojo se va directo a la alfombra clara. Silencio de dos segundos.',
    weight: 5,
    tags: ['vino', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Sal, agua fría y no llores, mi amor.'),
      DialogueLine(LineSpeaker.sebastian, 'No lloro. Estoy calculando cuánto costaba esa alfombra.'),
    ],
    delta: StatDelta(mood: -2, energy: 1, social: 1, bond: 1),
  ),

  // ───────────────────────────── CAFÉ ─────────────────────────────
  GameEvent(
    id: 'cafe_antes_de_hablar',
    category: EventCategory.cafe,
    title: 'Café primero, palabras después',
    scene:
        'En esta casa nadie habla antes del primer café. Hoy Maxito intenta romper la regla y recibe una mirada.',
    weight: 7,
    tags: ['cafe', 'manana', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Tengo una idea enorme...'),
      DialogueLine(LineSpeaker.sebastian, 'Café. Idea. En ese orden.',
          interruptsPrevious: true),
    ],
    delta: StatDelta(mood: 2, energy: 4, social: 1),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.manana]),
  ),
  GameEvent(
    id: 'cafe_cafetera_huelga',
    category: EventCategory.cafe,
    title: 'La cafetera italiana en huelga',
    scene:
        'La cafetera de siempre tiene la junta gastada y hoy decidió tirar todo el agua por la cocina.',
    weight: 4,
    tags: ['cafe', 'comedia', 'crisis menor'],
    lines: [
      DialogueLine(LineSpeaker.sebastian,
          'Nyet. No me hables. Estoy de luto por el café de la mañana.'),
      DialogueLine(LineSpeaker.maxito, 'Compramos junta nueva y un cortado de premio.'),
    ],
    delta: StatDelta(mood: -1, energy: 2, social: 2),
  ),
  GameEvent(
    id: 'cafe_bar_de_barrio',
    category: EventCategory.cafe,
    title: 'Café con leche en el bar de barrio',
    scene:
        'Bajan a la esquina, piden dos cafés y un croissant para compartir. El camarero ya sabe cómo lo toman.',
    weight: 6,
    tags: ['cafe', 'barrio', 'salida corta'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Él ya sabe que vos lo tomás sin azúcar.'),
      DialogueLine(LineSpeaker.sebastian, 'Y sabe que vos pedís dos y te comés uno y medio.'),
    ],
    delta: StatDelta(mood: 3, energy: 3, social: 4, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.mediodia],
    ),
  ),
  GameEvent(
    id: 'cafe_insomnio_libro',
    category: EventCategory.cafe,
    title: 'Café a la madrugada y un libro',
    scene:
        'No hay sueño. Se hace café cargado, se lee en voz baja y el piso cruje cada vez que uno se mueve.',
    weight: 4,
    tags: ['cafe', 'madrugada', 'silencio'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Leé para mí, que tu voz me ordena la cabeza.'),
      DialogueLine(LineSpeaker.maxito, 'Leo, pero si me quedo dormido vos seguís solo.'),
    ],
    delta: StatDelta(mood: 2, energy: -3, social: 2, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.madrugada],
      energyAtLeast: 40,
    ),
  ),

  // ───────────────────────────── LLUVIA ─────────────────────────────
  GameEvent(
    id: 'lluvia_balcon_abierto',
    category: EventCategory.lluvia,
    title: 'Lluvia en Barcelona',
    scene:
        'Llueve fuerte y los dos dejan la puerta del balcón abierta para escucharla. El aire huele a piedra mojada.',
    weight: 7,
    tags: ['lluvia', 'balcon', 'clima'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Vení, escuchá. Suena como si la ciudad respirara.'),
      DialogueLine(LineSpeaker.sebastian, 'En Buenos Aires esta lluvia dura diez minutos. Acá se queda a vivir.'),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 2, bond: 3),
  ),
  GameEvent(
    id: 'lluvia_paraguas_para_dos',
    category: EventCategory.lluvia,
    title: 'Un paraguas para dos',
    scene:
        'Vuelven del mercado con un paraguas chico, un hombro mojado cada uno y el bolso apretado contra el pecho.',
    weight: 6,
    tags: ['lluvia', 'salida corta', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'El paraguas es mío, pero el hombro mojado es tuyo.'),
      DialogueLine(LineSpeaker.maxito, 'Caminá más rápido y dejá de hacer cuentas.'),
    ],
    delta: StatDelta(mood: 2, energy: -2, social: 3, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.noche],
    ),
  ),
  GameEvent(
    id: 'lluvia_plan_cancelado',
    category: EventCategory.lluvia,
    title: 'Se cae el plan y no importa',
    scene:
        'Iban a salir, pero el cielo se puso de plomo. Se sacan los zapatos, se quedan en casa y no se arrepienten.',
    weight: 6,
    tags: ['lluvia', 'piso'],
    lines: [
      DialogueLine(LineSpeaker.maxito, '¿Lo dejamos para el sábado?'),
      DialogueLine(LineSpeaker.sebastian, 'Lo dejamos para siempre si querés. Traé la manta.'),
    ],
    delta: StatDelta(mood: 3, energy: 2, social: 2, bond: 2),
  ),
  GameEvent(
    id: 'lluvia_calcetines_mojados',
    category: EventCategory.lluvia,
    title: 'Los calcetines empapados',
    scene:
        'Un charco escondido, una zapatilla con agujero y un pie que hace un ruido raro al caminar por el pasillo.',
    weight: 5,
    tags: ['lluvia', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Hace un ruido de dibujito animado.'),
      DialogueLine(LineSpeaker.sebastian, 'No me saques fotos. Ni se te ocurra.',
          interruptsPrevious: true),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 1),
  ),

  // ───────────────────────────── BALCÓN ─────────────────────────────
  GameEvent(
    id: 'balcon_atardecer_sillas',
    category: EventCategory.balcon,
    title: 'Atardecer con sillas plegables',
    scene:
        'Dos sillas de metal, una cerveza fría y la luz naranja que entra por los edificios de enfrente.',
    weight: 7,
    tags: ['balcon', 'atardecer'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Esta luz la podríamos vender.'),
      DialogueLine(LineSpeaker.sebastian, 'La luz es gratis. Lo que se paga es el alquiler.'),
    ],
    delta: StatDelta(mood: 4, social: 3, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.noche],
    ),
  ),
  GameEvent(
    id: 'balcon_plantas_charla',
    category: EventCategory.balcon,
    title: 'Charla de plantas',
    scene:
        'Maxito habla con las plantas y jura que una albahaca está «contenta». Sebastián revisa si hay algo rescatable para la cena.',
    weight: 5,
    tags: ['balcon', 'plantas', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Esta albahaca me debe estar escuchando.'),
      DialogueLine(LineSpeaker.sebastian, 'Si escucha, sabe que queremos usarla el jueves.'),
    ],
    delta: StatDelta(mood: 2, social: 2, bond: 1),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.mediodia]),
  ),
  GameEvent(
    id: 'balcon_vecina_riega',
    category: EventCategory.balcon,
    title: 'La vecina de enfrente riega',
    scene:
        'La vecina de enfrente riega sus geranios a la misma hora de siempre y saluda con la mano, como cada tarde.',
    weight: 5,
    tags: ['balcon', 'vecinos', 'barrio'],
    lines: [
      DialogueLine(LineSpeaker.ambiente, 'Un saludo de mano, la regadera levantada, nada más.'),
      DialogueLine(LineSpeaker.maxito, 'Es la persona más puntual de Barcelona.'),
    ],
    delta: StatDelta(mood: 2, social: 3),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.tarde]),
  ),
  GameEvent(
    id: 'balcon_estrellas_madrugada',
    category: EventCategory.balcon,
    title: 'Tres estrellas y una luna confundida',
    scene:
        'La ciudad tapa casi todo el cielo, pero quedan tres estrellas y una luna pálida que igual les alcanza.',
    weight: 4,
    tags: ['balcon', 'madrugada', 'silencio'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'En Buenos Aires tampoco se veían. Uno igual las busca.'),
      DialogueLine(LineSpeaker.maxito, 'Encontré tres. Se las regalo todas a vos.'),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 2, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.madrugada],
      bondAtLeast: 55,
    ),
  ),
  GameEvent(
    id: 'balcon_silencio_comodo',
    category: EventCategory.balcon,
    title: 'Silencio bien usado',
    scene:
        'Están los dos en el balcón sin hablar, y el silencio se siente cómodo, de esos que no hay que llenar.',
    weight: 4,
    tags: ['balcon', 'silencio'],
    lines: [
      DialogueLine(LineSpeaker.ambiente,
          'Veinte minutos en silencio. Ninguno de los dos se mueve.'),
    ],
    delta: StatDelta(mood: 3, energy: 1, social: -1, bond: 5),
    conditions: EventConditions(bondAtLeast: 80),
  ),

  // ───────────────────────────── GRÀCIA ─────────────────────────────
  GameEvent(
    id: 'gracia_plaza_sol',
    category: EventCategory.gracia,
    title: 'Vermut en una plaza de Gràcia',
    scene:
        'Terrazas llenas, gente con perro, alguien tocando la guitarra en el suelo. Encuentran dos taburetes por pura suerte.',
    weight: 4,
    tags: ['salida', 'gracia', 'barrio'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Conseguí dos asientos. Considerame tu héroe.'),
      DialogueLine(LineSpeaker.sebastian, 'Heroína. Y sí, te debo un vermut.'),
    ],
    delta: StatDelta(mood: 5, energy: -2, social: 5, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
      bondAtLeast: 40,
    ),
  ),
  GameEvent(
    id: 'gracia_festa_major',
    category: EventCategory.gracia,
    title: 'Festa Major de Gràcia',
    scene:
        'Calles decoradas hasta el techo, charanga a lo lejos y un olor a pan recién hecho que los lleva de la mano.',
    weight: 2,
    tags: ['salida', 'gracia', 'raro', 'fiesta'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Raro: hay que venir una vez al año y no perderse.'),
      DialogueLine(LineSpeaker.maxito, 'Perdámonos un rato más, total el barrio es chico.'),
    ],
    delta: StatDelta(mood: 6, energy: -4, social: 6, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      weekendOnly: true,
      minDayIndex: 3,
    ),
  ),
  GameEvent(
    id: 'gracia_vinilos_y_libros',
    category: EventCategory.gracia,
    title: 'Vinilos y libros en Gràcia',
    scene:
        'Entran «solo a mirar» y salen con un disco viejo, dos libros de segunda mano y un póster que no les va a entrar en la pared.',
    weight: 4,
    tags: ['salida', 'gracia', 'compras'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'El póster lo pegamos en la puerta.'),
      DialogueLine(LineSpeaker.sebastian, 'Tenemos tres pósters, dos puertas. Hagamos la cuenta.'),
    ],
    delta: StatDelta(mood: 4, energy: -2, social: 3, bond: 2),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.tarde]),
  ),

  // ───────────────────────────── EIXAMPLE ─────────────────────────────
  GameEvent(
    id: 'eixample_paseo_calles',
    category: EventCategory.eixample,
    title: 'Caminar el Eixample sin plan',
    scene:
        'Caminan en diagonal sin destino, miran los balcones modernistas y discuten cuál edificio es más lindo.',
    weight: 5,
    tags: ['salida', 'eixample', 'paseo'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Ese balcón con hierro parece hecho de encaje.'),
      DialogueLine(LineSpeaker.maxito, 'Ese otro tiene una bici colgada, y gana.'),
    ],
    delta: StatDelta(mood: 4, energy: -2, social: 4, bond: 2),
  ),
  GameEvent(
    id: 'eixample_pasteleria_luz',
    category: EventCategory.eixample,
    title: 'Pastelería con luz antigua',
    scene:
        'Entran por el olor. Compran dos pasteles que no pensaban comprar y los comen en el mostrador, como dos delincuentes dulces.',
    weight: 4,
    tags: ['salida', 'eixample', 'comida'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'El de crema es mío, ya me lo llené de azúcar.'),
      DialogueLine(LineSpeaker.sebastian, 'El de chocolate es mío. Aprendí a defender lo mío.'),
    ],
    delta: StatDelta(mood: 5, energy: 1, social: 3),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.tarde]),
  ),
  GameEvent(
    id: 'eixample_azotea_amigos',
    category: EventCategory.eixample,
    title: 'Azotea de amigos en el Eixample',
    scene:
        'Los invita un amigo con terraza de verdad. Sillas distintas, luces de colores y vistas de techos con antenas.',
    weight: 3,
    tags: ['salida', 'eixample', 'amigos', 'noche'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Desde acá arriba Barcelona parece ordenada.'),
      DialogueLine(LineSpeaker.sebastian, 'Ves todo el Eixample y ni un ruido de obra. Milagro.'),
    ],
    delta: StatDelta(mood: 5, energy: -2, social: 6, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      bondAtLeast: 45,
    ),
  ),

  // ───────────────────────────── RAVAL ─────────────────────────────
  GameEvent(
    id: 'raval_bar_pequeño',
    category: EventCategory.raval,
    title: 'Bar minúsculo en el Raval',
    scene:
        'Seis taburetes, azulejos antiguos y un dueño que sirve vermut sin preguntar. Los dos apretados y felices.',
    weight: 4,
    tags: ['salida', 'raval', 'noche'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Acá el ruido es parte del menú.'),
      DialogueLine(LineSpeaker.maxito, 'Y las aceitunas son gratis. Subamos el ánimo.'),
    ],
    delta: StatDelta(mood: 4, energy: -2, social: 5, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      socialAtLeast: 35,
    ),
  ),
  GameEvent(
    id: 'raval_libreria_gato',
    category: EventCategory.raval,
    title: 'Librería vieja y un gato del local',
    scene:
        'Una librería de usados con un gato atigrado en la caja registradora. El gato no atiende a nadie.',
    weight: 4,
    tags: ['salida', 'raval', 'libros', 'gatos'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Es igual a vos, pero más responsable.'),
      DialogueLine(LineSpeaker.sebastian, 'Es igual a vos: duerme arriba de la plata.'),
    ],
    delta: StatDelta(mood: 4, energy: -1, social: 3, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.mediodia],
    ),
  ),
  GameEvent(
    id: 'raval_concierto_galeria',
    category: EventCategory.raval,
    title: 'Gig chiquito en una galería del Raval',
    scene:
        'Un concierto de treinta personas en un espacio que parece un living. Suena fuerte y suena bien.',
    weight: 3,
    tags: ['salida', 'raval', 'musica', 'raro'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Estamos a dos metros del baterista.'),
      DialogueLine(LineSpeaker.sebastian, 'A dos metros y sin entrada. Gracias, Barcelona.'),
    ],
    delta: StatDelta(mood: 5, energy: -3, social: 6, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      minDayIndex: 2,
    ),
  ),

  // ─────────────────────────── BARCELONETA ───────────────────────────
  GameEvent(
    id: 'barceloneta_arena_fria',
    category: EventCategory.barceloneta,
    title: 'Arena fría de mayo',
    scene:
        'El agua todavía está helada, pero igual se sacan las zapatillas y caminan por la orilla hasta mojarse los tobillos.',
    weight: 5,
    tags: ['salida', 'barceloneta', 'mar'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Está fría. Está fría. Está frííísima.'),
      DialogueLine(LineSpeaker.sebastian, 'Dejá de gritar, nos va a mirar toda la playa.'),
    ],
    delta: StatDelta(mood: 5, energy: -1, social: 4, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.mediodia],
    ),
  ),
  GameEvent(
    id: 'barceloneta_chiringuito',
    category: EventCategory.barceloneta,
    title: 'Comida de chiringuito',
    scene:
        'Un plato de calamares, dos cervezas y esa sensación rara de estar de vacaciones en la propia ciudad.',
    weight: 5,
    tags: ['salida', 'barceloneta', 'comida'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Hoy no cocinamos. Hoy es día de mantel de papel.'),
      DialogueLine(LineSpeaker.maxito, 'Y de arena en los pies. Es la prueba de que fue un buen día.'),
    ],
    delta: StatDelta(mood: 5, energy: 1, social: 4, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
    ),
  ),
  GameEvent(
    id: 'barceloneta_rompeolas',
    category: EventCategory.barceloneta,
    title: 'El rompeolas al atardecer',
    scene:
        'Se sientan sobre las piedras y miran los barcos. La luz se va cayendo sobre el puerto y nadie tiene apuro.',
    weight: 5,
    tags: ['salida', 'barceloneta', 'atardecer'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Podríamos quedarnos hasta que se apague todo.'),
      DialogueLine(LineSpeaker.sebastian, 'Mañana trabajamos. Pero sí, un rato más.'),
    ],
    delta: StatDelta(mood: 5, energy: -2, social: 4, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.noche],
    ),
  ),
  GameEvent(
    id: 'barceloneta_invierno_vacia',
    category: EventCategory.barceloneta,
    title: 'La Barceloneta en enero',
    scene:
        'La playa está vacía, con abrigo, gaviotas gordas y un puesto de churros que igual abre. El mar es de ellos.',
    weight: 3,
    tags: ['salida', 'barceloneta', 'invierno', 'raro'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Está vacía. Es la mejor versión de esta playa.'),
      DialogueLine(LineSpeaker.maxito, 'Compartimos un cono de churros con guantes. Un caos hermoso.'),
    ],
    delta: StatDelta(mood: 5, energy: -2, social: 3, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.tarde],
      weekdayOnly: true,
    ),
  ),

  // ───────────────────────────── MONTJUÏC ─────────────────────────────
  GameEvent(
    id: 'montjuic_jardines_subida',
    category: EventCategory.montjuic,
    title: 'Subida a Montjuïc con pereza',
    scene:
        'Suben los jardines parando cada diez escalones. Se sientan en un banco a discutir si vale la pena la cima.',
    weight: 4,
    tags: ['salida', 'montjuic', 'paseo'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Vale la pena, pero yo pago el funicular la próxima.'),
      DialogueLine(LineSpeaker.sebastian, 'Vos no pagás nunca el funicular. Lo sé desde hace años.'),
    ],
    delta: StatDelta(mood: 4, energy: -4, social: 3, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.mediodia],
    ),
  ),
  GameEvent(
    id: 'montjuic_castillo_puerto',
    category: EventCategory.montjuic,
    title: 'El castillo mirando el puerto',
    scene:
        'Llegaron arriba. Desde la muralla se ve todo el puerto y los tejados de la Barceloneta apretaditos.',
    weight: 4,
    tags: ['salida', 'montjuic', 'vistas'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Mirá: vivimos allá abajo, en el medio del ruido.'),
      DialogueLine(LineSpeaker.maxito, 'Desde acá el ruido no existe. Me gusta igual'),
    ],
    delta: StatDelta(mood: 5, energy: -2, social: 3, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.manana],
      bondAtLeast: 45,
    ),
  ),
  GameEvent(
    id: 'montjuic_fuentes_noche',
    category: EventCategory.montjuic,
    title: 'Fuentes de Montjuïc encendidas',
    scene:
        'Un espectáculo de agua, luz y música con muchísima gente. Igual encuentran un huequito con vista libre.',
    weight: 3,
    tags: ['salida', 'montjuic', 'noche', 'raro'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Quedate cerca, que acá te perdés en dos minutos.'),
      DialogueLine(LineSpeaker.sebastian, 'No me pierdo. Te estoy mirando a vos el espectáculo.'),
    ],
    delta: StatDelta(mood: 5, energy: -3, social: 6, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      bondAtLeast: 50,
    ),
  ),

  // ───────────────────────────── SITGES ─────────────────────────────
  GameEvent(
    id: 'sitges_tren_una_hora',
    category: EventCategory.sitges,
    title: 'Tren de una hora a Sitges',
    scene:
        'Al final se decidieron: un tren de cercanías, ventana, auriculares que comparten y la costa apareciendo a la derecha.',
    weight: 3,
    tags: ['salida', 'sitges', 'viaje', 'raro'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Escapada sin plan. No llevamos ni protector solar.'),
      DialogueLine(LineSpeaker.sebastian, 'En octubre no hace falta. Davai, confiá en mí.'),
    ],
    delta: StatDelta(mood: 6, energy: -2, social: 4, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.manana, TimeOfDaySlot.mediodia],
      weekendOnly: true,
      bondAtLeast: 55,
    ),
  ),
  GameEvent(
    id: 'sitges_iglesia_helado',
    category: EventCategory.sitges,
    title: 'Iglesia junto al mar y un helado',
    scene:
        'Sitges en calma: callejones blancos, la iglesia parada sobre las rocas y un helado de dos gustos que se derrite rápido.',
    weight: 3,
    tags: ['salida', 'sitges', 'comida'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'El helado es de dos sabores y los dos son míos.'),
      DialogueLine(LineSpeaker.maxito, 'Eso no lo acordamos así. Dame un bocado o guerra.'),
    ],
    delta: StatDelta(mood: 6, energy: -1, social: 4, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.mediodia, TimeOfDaySlot.tarde],
      weekendOnly: true,
    ),
  ),
  GameEvent(
    id: 'sitges_paseo_nocturno',
    category: EventCategory.sitges,
    title: 'Sitges de noche, paseo junto al agua',
    scene:
        'Esperan el último tren paseando por el espigón. Hay una brisa fresca y un bar todavía abierto con luces bajas.',
    weight: 2,
    tags: ['salida', 'sitges', 'noche', 'raro'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Si perdemos el tren, dormimos en la playa.'),
      DialogueLine(LineSpeaker.sebastian, 'Si perdemos el tren, vos explicás el lunes en el café.'),
    ],
    delta: StatDelta(mood: 6, energy: -4, social: 5, bond: 5),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche],
      weekendOnly: true,
      bondAtLeast: 60,
      minDayIndex: 4,
    ),
  ),

  // ───────────────────────────── METRO ─────────────────────────────
  GameEvent(
    id: 'metro_ultimo_tren',
    category: EventCategory.metro,
    title: 'El último metro después de la fiesta',
    scene:
        'El vagón casi vacío, las luces blancas, los dos con la música todavía en el cuerpo y los pies cansados.',
    weight: 5,
    tags: ['metro', 'fiesta', 'noche'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Todavía me zumba la cabeza.'),
      DialogueLine(LineSpeaker.sebastian, 'Yo tengo zumbando los pies. Bajemos una parada antes.'),
    ],
    delta: StatDelta(mood: 4, energy: -5, social: 4, bond: 3),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.madrugada, TimeOfDaySlot.noche],
      socialAtLeast: 45,
    ),
  ),
  GameEvent(
    id: 'metro_tarjeta_del_fondo',
    category: EventCategory.metro,
    title: 'La tarjeta que siempre está en el fondo',
    scene:
        'En el molinete, la T-casual no aparece. Revolución de mochila, papeles viejos y al final la tarjeta estaba en un bolsillo interno.',
    weight: 5,
    tags: ['metro', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Yo te espero del otro lado con paciencia infinita.'),
      DialogueLine(LineSpeaker.maxito, 'Paciencia infinita: encontró la tarjeta. Pasá vos primero.'),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 2),
  ),
  GameEvent(
    id: 'metro_andana_dos_mañana',
    category: EventCategory.metro,
    title: 'Andén a las dos de la mañana',
    scene:
        'Esperan el metro en un andén largo y vacío. El cartel dice que faltan ocho minutos y ellos creen cero.',
    weight: 4,
    tags: ['metro', 'madrugada'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Ocho minutos. Mentira. Siempre mienten.'),
      DialogueLine(LineSpeaker.sebastian, 'Sentate en el banco y contame algo del bar.'),
    ],
    delta: StatDelta(mood: 2, energy: -3, social: 3, bond: 2),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.madrugada]),
  ),

  // ───────────────────────── SUPERMERCADO ─────────────────────────
  GameEvent(
    id: 'super_noche_compra_absurda',
    category: EventCategory.supermercado,
    title: 'Supermercado a las once',
    scene:
        'Entran por leche y salen con leche, un vino, galletas de dinosaurio y una almohada con forma de perro.',
    weight: 6,
    tags: ['supermercado', 'noche', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'La almohada de perro la necesita la casa. Es un bien común.'),
      DialogueLine(LineSpeaker.sebastian, 'La casa no pidió nada y ya tenemos tres almohadas.'),
    ],
    delta: StatDelta(mood: 4, energy: -1, social: 3, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.madrugada],
    ),
  ),
  GameEvent(
    id: 'super_caja_lenta',
    category: EventCategory.supermercado,
    title: 'Cola lenta, decisiones rápidas',
    scene:
        'Un solo cajero, ocho personas y un señor que busca monedas exactas como si fuera un deporte.',
    weight: 5,
    tags: ['supermercado', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Soy el tercero en la cola y ya escribí un testamento.'),
      DialogueLine(LineSpeaker.maxito, 'Yo compré una chocolatina y la terminé esperando.'),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 2),
  ),
  GameEvent(
    id: 'super_cena_de_restos',
    category: EventCategory.supermercado,
    title: 'Cena heroica con restos',
    scene:
        'Sin comprar nada nuevo: media berenjena, arroz de ayer, un huevo y una salsa inventada en el momento.',
    weight: 5,
    tags: ['supermercado', 'cocina', 'ahorro'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Esto en un restaurante sería plato de autor.'),
      DialogueLine(LineSpeaker.sebastian, 'Esto es un arroz con berenjena y sin culpa. Comé.'),
    ],
    delta: StatDelta(mood: 3, energy: 2, social: 2, bond: 1),
  ),
  GameEvent(
    id: 'super_carrito_cojo',
    category: EventCategory.supermercado,
    title: 'El carrito que tira a la izquierda',
    scene:
        'El carrito tiene la rueda loca y los dos van corrigiendo el rumbo por los pasillos como si fueran alineados.',
    weight: 4,
    tags: ['supermercado', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Vamos en zigzag y la gente nos mira.'),
      DialogueLine(LineSpeaker.sebastian, 'Que miren. Nosotros llegamos igual a la caja.'),
    ],
    delta: StatDelta(mood: 3, energy: -1, social: 2, bond: 1),
  ),

  // ──────────────────────── RUTINA Y DISPARATES ────────────────────────
  GameEvent(
    id: 'rutina_regadera_inundacion',
    category: EventCategory.rutina,
    title: 'La regadera que se cae sola',
    scene:
        'La regadera del baño se resbala y un chorro de agua cruza todo el pasillo. Freno heroico con una toalla.',
    weight: 5,
    tags: ['rutina', 'comedia', 'crisis menor'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Toalla. Toalla. ¡Otra toalla!'),
      DialogueLine(LineSpeaker.sebastian, 'Ya está, ya está. Solo se mojó todo el pasillo.'),
    ],
    delta: StatDelta(mood: 2, energy: -2, social: 2),
  ),
  GameEvent(
    id: 'rutina_alarma_muda',
    category: EventCategory.rutina,
    title: 'La alarma que no sonó',
    scene:
        'Se durmieron cuarenta minutos más. El día arranca corrido y con una carrera por el café que igual termina bien.',
    weight: 4,
    tags: ['rutina', 'manana', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Despertador silencioso. Sin palabras.'),
      DialogueLine(LineSpeaker.maxito, 'Yo lo escuché, me pareció que era de otro.'),
    ],
    delta: StatDelta(mood: 1, energy: -2, social: 2),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.manana]),
  ),
  GameEvent(
    id: 'rutina_calcetines_desaparecidos',
    category: EventCategory.rutina,
    title: 'Los calcetines desaparecidos',
    scene:
        'La lavadora se quedó con tres calcetines sin pareja. La casa tiene una lista de sospechosos y ningún culpable.',
    weight: 4,
    tags: ['rutina', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Hay un agujero negro y está entre el tambor y el rincon del balcón.'),
      DialogueLine(LineSpeaker.sebastian, 'Comprá todos iguales y se termina el drama nacional.'),
    ],
    delta: StatDelta(mood: 2, social: 1),
  ),
  GameEvent(
    id: 'rutina_vecino_taladro',
    category: EventCategory.rutina,
    title: 'El taladro del vecino',
    scene:
        'El vecino de arriba decide arreglar algo justo ahora. El ruido entra por el techo y los dos hablan más fuerte.',
    weight: 5,
    tags: ['rutina', 'vecinos', 'comedia'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Es un ritmo. Le podríamos poner música encima.'),
      DialogueLine(LineSpeaker.sebastian, 'Ese es el nivel de resignación que admiraba en Barcelona.'),
    ],
    delta: StatDelta(mood: -1, energy: -1, social: 2, bond: 1),
  ),
  GameEvent(
    id: 'rutina_tortilla_debate',
    category: EventCategory.rutina,
    title: 'Debate sobre la tortilla',
    scene:
        'Uno la quiere con cebolla y el otro sin. La discusión es seria, larga y absolutamente doméstica.',
    weight: 6,
    tags: ['rutina', 'comedia', 'cocina'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Con cebolla es la versión buena. Es evidente.'),
      DialogueLine(LineSpeaker.sebastian, 'La cebolla se lleva todo el sabor. Es un secuestro.'),
      DialogueLine(LineSpeaker.maxito, 'Hacemos dos, entonces. Media para cada uno.',
          interruptsPrevious: true),
    ],
    delta: StatDelta(mood: 4, energy: 1, social: 3, bond: 2),
  ),
  GameEvent(
    id: 'rutina_cocina_harina',
    category: EventCategory.rutina,
    title: 'La harina que se cayó entera',
    scene:
        'Un paquete de harina abierto, un movimiento raro y la cocina convertida en un paisaje nevado.',
    weight: 4,
    tags: ['rutina', 'comedia', 'cocina'],
    lines: [
      DialogueLine(LineSpeaker.maxito, 'Podemos decir que fue un experimento.'),
      DialogueLine(LineSpeaker.sebastian, 'Podemos limpiar. Empezá por ahí, científicamente.'),
    ],
    delta: StatDelta(mood: 3, energy: -2, social: 2),
  ),
  GameEvent(
    id: 'rutina_todo_desordenado',
    category: EventCategory.rutina,
    title: 'Ordenar la casa los dos juntos',
    scene:
        'Se proponen ordenar en serio. Empiezan por la música, siguen por un cajón y terminan mirando fotos viejas en el suelo.',
    weight: 5,
    tags: ['rutina', 'piso', 'memoria'],
    lines: [
      DialogueLine(LineSpeaker.sebastian, 'Ese cajón era una trampa y vos lo sabías.'),
      DialogueLine(LineSpeaker.maxito, 'Vale, pero encontré la foto del primer día. Mirá esa cara.'),
    ],
    delta: StatDelta(mood: 4, energy: -1, social: 3, bond: 4),
  ),
];

/// Eventos que salen como plan raro (fuera del piso).
List<GameEvent> get kOutingEvents =>
    kEventCatalog.where((event) => event.isOuting).toList(growable: false);

Map<String, GameEvent> get kEventsById =>
    {for (final event in kEventCatalog) event.id: event};
