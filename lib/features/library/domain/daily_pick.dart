import 'dart:math';

import 'package:sonaplay/features/library/domain/entities/song.dart';

/// Why the day's song was chosen
enum DailyKind { favorite, discover }

typedef DailyPick = ({Song song, DailyKind kind, String phrase});

/// Same value all day, so the card doesn't change when the app reopens
int daySeed(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

/// One phrase and one song per calendar day. Even days bring back a
/// favourite (most played); odd days, or no history yet, one barely heard.
DailyPick? pickDaily(List<Song> songs, Map<String, int> plays, DateTime day) {
  // Skips voice notes and short clips
  final candidates = [
    for (final s in songs)
      if ((s.duration ?? 0) >= 90000) s,
  ];
  if (candidates.isEmpty) return null;
  final seed = daySeed(day);
  final random = Random(seed);
  final phrase = dailyPhrases[Random(seed + 1).nextInt(dailyPhrases.length)];

  int count(Song s) => plays[s.id] ?? 0;
  final favorites = [
    for (final s in candidates)
      if (count(s) >= 3) s,
  ]..sort((a, b) => count(b).compareTo(count(a)));
  if (seed.isEven && favorites.isNotEmpty) {
    final top = favorites.take(10).toList();
    return (
      song: top[random.nextInt(top.length)],
      kind: DailyKind.favorite,
      phrase: phrase,
    );
  }
  final rare = [
    for (final s in candidates)
      if (count(s) < 2) s,
  ];
  final pool = rare.isEmpty ? candidates : rare;
  return (
    song: pool[random.nextInt(pool.length)],
    kind: DailyKind.discover,
    phrase: phrase,
  );
}

/// Greeting for the hour of the day
String greeting(DateTime now) => switch (now.hour) {
  >= 5 && < 12 => 'Buenos días',
  >= 12 && < 19 => 'Buenas tardes',
  _ => 'Buenas noches',
};

const dailyPhrases = [
  // Frases
  'La música expresa lo que no puede ser dicho y aquello que no puede permanecer en silencio. — Victor Hugo',
  'Sin música, la vida sería un error. — Friedrich Nietzsche',
  'Donde fallan las palabras, habla la música. — Hans Christian Andersen',
  'La música es el corazón de la vida. — Franz Liszt',
  'Un día sin música es un día perdido.',
  'Cada canción es una puerta; hoy elige una que no hayas abierto.',
  'Lo que hoy cuesta, mañana se canta.',
  'No esperes el momento perfecto: ponle banda sonora al que tienes.',
  'Paso a paso también se llega lejos, sobre todo con buen ritmo.',
  'Hoy es un buen día para empezar algo, aunque sea una playlist.',
  'Respira hondo. La siguiente canción es tuya.',
  'Tu energía se contagia más rápido que un estribillo pegadizo.',
  'Las mejores ideas llegan entre canción y canción.',
  'Cuando todo suena a ruido, busca tu melodía.',
  // Consejos
  'Consejo: escucha a un volumen moderado; tus oídos te lo agradecerán dentro de 20 años.',
  'Consejo: toma un descanso de los audífonos cada hora.',
  'Consejo: mantén presionada una canción para seleccionar varias a la vez.',
  'Consejo: desliza la carátula en el reproductor para cambiar de canción.',
  'Consejo: prueba el ecualizador con el ajuste "Voces" para canciones acústicas.',
  'Consejo: personaliza el fondo de la app desde Ajustes → Apariencia.',
  'Consejo: el temporizador de apagado pausa la música por ti antes de dormir.',
  'Consejo: toca la canción que suena para abrir el reproductor.',
  'Consejo: una playlist para cada estado de ánimo te ahorra tiempo.',
  'Consejo: escuchar música mientras estudias ayuda más si es instrumental.',
  'Consejo: hidrátate. Cantar a todo pulmón también cansa.',
  // Chistes
  '¿Qué le dice una nota musical a otra? "¡Nos vemos en el pentagrama!"',
  '¿Por qué el músico llevó una escalera al concierto? Para alcanzar las notas altas.',
  '¿Cuál es el colmo de un músico? Que su esposa se llame Mi y su hija Do.',
  '¿Por qué el piano no puede abrir la puerta? Porque perdió las llaves... y solo le quedan teclas.',
  '¿Qué hace una abeja en el gimnasio? ¡Zum-ba!',
  'Mi vecino toca la batería a las 3 a. m. Al menos ya no necesito despertador.',
  '¿Cómo se despiden los músicos? "¡Hasta la próxima nota!"',
  '¿Por qué los esqueletos no tocan música en las fiestas? Porque no tienen órganos.',
  '—Doctor, no dejo de cantar "Despacito". —Tranquilo, se le pasará... pasito a pasito.',
  '¿Qué le dijo el DJ a la pizza? "Tienes buena mezcla."',
];
