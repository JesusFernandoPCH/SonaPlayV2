import 'package:flutter_test/flutter_test.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/library/domain/daily_pick.dart';

SongModel _song(String id, int seconds) => SongModel(
  id: id,
  title: id,
  artist: 'A',
  duration: seconds * 1000,
  filePath: '/m/$id.mp3',
);

void main() {
  final songs = [
    for (var i = 0; i < 20; i++) _song('$i', 200),
    _song('clip', 20),
  ];
  final even = DateTime(2026, 10, 20); // seed 20261020
  final odd = DateTime(2026, 10, 19);

  test('same pick all day, never short clips', () {
    for (final day in [even, odd]) {
      final a = pickDaily(songs, {}, day)!;
      final b = pickDaily(songs, {}, day.add(const Duration(hours: 20)))!;
      expect(a.song.id, b.song.id);
      expect(a.phrase, b.phrase);
      expect(a.song.id, isNot('clip'));
    }
  });

  test('even days bring a favourite, odd days a rarely played song', () {
    final plays = {for (var i = 0; i < 18; i++) '$i': 10};
    final fav = pickDaily(songs, plays, even)!;
    expect(fav.kind, DailyKind.favorite);
    expect(plays[fav.song.id], 10);
    final rare = pickDaily(songs, plays, odd)!;
    expect(rare.kind, DailyKind.discover);
    expect(['18', '19'], contains(rare.song.id));
  });

  test('no history or no songs', () {
    expect(pickDaily(songs, {}, even)!.kind, DailyKind.discover);
    expect(pickDaily([_song('x', 10)], {}, even), isNull);
  });

  test('greeting by hour', () {
    expect(greeting(DateTime(2026, 1, 1, 9)), 'Buenos días');
    expect(greeting(DateTime(2026, 1, 1, 15)), 'Buenas tardes');
    expect(greeting(DateTime(2026, 1, 1, 1)), 'Buenas noches');
  });
}
