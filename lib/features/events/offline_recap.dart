/// Recuerdos cortos de lo que pasó mientras el jugador no estaba.
///
/// Todos se muestran con el prefijo `Mientras no estabas…` delante.
/// Son 18, con condiciones de hora, ánimo y conexión para que el resumen
/// de bienvenida cambie según cuánto tiempo estuvo uno fuera y cómo quedó la casa.
library;

import 'models.dart';

/// Los recuerdos «Mientras no estabas…».
const List<OfflineRecap> kOfflineRecaps = [
  OfflineRecap(
    id: 'off_cafe_frio',
    text: 'Sebastián hizo café para los dos y se le enfrió el tuyo en la mesada.',
    weight: 8,
    tags: ['piso', 'cafe'],
    delta: StatDelta(mood: -1, social: 1),
  ),
  OfflineRecap(
    id: 'off_plancha_sin_planchar',
    text: 'Maxito quiso ordenar el armario y terminó probándose ropa vieja frente al espejo.',
    weight: 7,
    tags: ['piso', 'comedia'],
    delta: StatDelta(mood: 2, energy: -1),
  ),
  OfflineRecap(
    id: 'off_montserrat_crecio',
    text: 'Montserrat, la suculenta del balcón, sobrevivió y hasta sacó una hoja nueva.',
    weight: 6,
    tags: ['balcon', 'plantas'],
    delta: StatDelta(mood: 1, bond: 1),
  ),
  OfflineRecap(
    id: 'off_siesta_larga',
    text: 'Se quedaron dormidos en el sofá con una serie a medias y nadie se acuerda del final.',
    weight: 7,
    tags: ['piso', 'descanso'],
    delta: StatDelta(mood: 1, energy: 3),
  ),
  OfflineRecap(
    id: 'off_tortilla_dos_versiones',
    text: 'Discutieron otra vez por la tortilla con cebolla y terminaron haciendo dos.',
    weight: 6,
    tags: ['cocina', 'comedia'],
    delta: StatDelta(mood: 2, bond: 1),
  ),
  OfflineRecap(
    id: 'off_lluvia_balcon',
    text: 'Dejaron la puerta del balcón abierta para escuchar la lluvia y se mojó media alfombra.',
    weight: 6,
    tags: ['lluvia', 'balcon'],
    delta: StatDelta(mood: 1, energy: -1),
  ),
  OfflineRecap(
    id: 'off_barrio_paseo_corto',
    text: 'Bajaron a la esquina a comprar pan y volvieron con pan, flores y dos helados.',
    weight: 7,
    tags: ['barrio', 'salida corta'],
    delta: StatDelta(mood: 2, social: 1),
  ),
  OfflineRecap(
    id: 'off_vinilo_repetido',
    text: 'El disco quedó dando vueltas con la aguja al final y nadie se levantó a sacarlo.',
    weight: 6,
    tags: ['musica'],
    delta: StatDelta(mood: 1, energy: -1),
  ),
  OfflineRecap(
    id: 'off_metro_ultimo',
    text: 'Volvieron en el último metro, sentados uno contra el otro, casi dormidos.',
    weight: 5,
    tags: ['metro', 'fiesta'],
    delta: StatDelta(mood: 2, energy: -2, bond: 2),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.madrugada, TimeOfDaySlot.noche],
    ),
  ),
  OfflineRecap(
    id: 'off_super_almohada_perro',
    text: 'En el supermercado de la noche compraron una almohada con forma de perro «para la casa».',
    weight: 5,
    tags: ['supermercado', 'comedia'],
    delta: StatDelta(mood: 2, social: 1),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.madrugada]),
  ),
  OfflineRecap(
    id: 'off_manana_lenta',
    text: 'El café de la mañana se estiró hasta el mediodía, con las manos calentitas alrededor de la taza.',
    weight: 7,
    tags: ['cafe', 'manana'],
    delta: StatDelta(mood: 2, energy: 2),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.manana]),
  ),
  OfflineRecap(
    id: 'off_tarde_sillas',
    text: 'Sacaron las sillas al balcón y se quedaron viendo la luz naranja sobre los edificios.',
    weight: 6,
    tags: ['balcon', 'atardecer'],
    delta: StatDelta(mood: 3, bond: 2),
    conditions: EventConditions(timeOfDay: [TimeOfDaySlot.tarde, TimeOfDaySlot.noche]),
  ),
  OfflineRecap(
    id: 'off_vecina_saludo',
    text: 'La vecina de enfrente les preguntó por vos y mandó saludos.',
    weight: 5,
    tags: ['vecinos', 'barrio'],
    delta: StatDelta(social: 2, mood: 1),
  ),
  OfflineRecap(
    id: 'off_abrazo_largo',
    text: 'Se quedaron un rato abrazados sin decir nada, de esos silencios que arreglan el día.',
    weight: 6,
    tags: ['mimo'],
    delta: StatDelta(mood: 3, bond: 3),
    conditions: EventConditions(moodAtMost: MoodLevel.bajo),
  ),
  OfflineRecap(
    id: 'off_playlist_nueva',
    text: 'Maxito armó una playlist nueva y tu canción quedó primera, sin avisarte.',
    weight: 6,
    tags: ['musica', 'amor'],
    delta: StatDelta(mood: 3, bond: 3),
    conditions: EventConditions(bondAtLeast: 50),
  ),
  OfflineRecap(
    id: 'off_carta_a_mano',
    text: 'Sebastián te dejó una nota en la mesa que dice «volvé pronto, gato».',
    weight: 6,
    tags: ['amor', 'piso'],
    delta: StatDelta(mood: 3, bond: 3),
    conditions: EventConditions(bondAtLeast: 55),
  ),
  OfflineRecap(
    id: 'off_noche_larga_casa',
    text: 'Hablaron hasta muy tarde, con el vino a medias, sobre cosas que no se dicen de día.',
    weight: 5,
    tags: ['noche', 'piso'],
    delta: StatDelta(mood: 2, energy: -2, bond: 4),
    conditions: EventConditions(
      timeOfDay: [TimeOfDaySlot.noche, TimeOfDaySlot.madrugada],
      bondAtLeast: 60,
    ),
  ),
  OfflineRecap(
    id: 'off_extraño_tu_lado',
    text: 'El lado de la cama donde dormís quedó demasiado grande y lo dijeron en voz alta.',
    weight: 5,
    tags: ['amor', 'casa'],
    delta: StatDelta(mood: 1, social: -1, bond: 3),
    conditions: EventConditions(bondAtLeast: 65),
  ),
];

Map<String, OfflineRecap> get kOfflineRecapsById =>
    {for (final recap in kOfflineRecaps) recap.id: recap};
