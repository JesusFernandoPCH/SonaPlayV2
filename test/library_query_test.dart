import 'package:flutter_test/flutter_test.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';
import 'package:sonaplay/features/library/domain/library_query.dart';

SongModel _song(
  String id, {
  String title = 'T',
  String artist = 'A',
  String? album,
  int? duration,
  String dir = '/music',
}) => SongModel(
  id: id,
  title: title,
  artist: artist,
  album: album,
  duration: duration,
  filePath: '$dir/$id.mp3',
);

void main() {
  final songs = [
    _song('1', title: 'beta', artist: 'Zoe', duration: 300, dir: '/m/Rock'),
    _song('2', title: 'Alpha', artist: 'adele', album: 'X', duration: 100),
    _song('3', title: 'gamma', artist: 'Bob', album: 'Y', dir: '/m/Rock'),
  ];
  List<String> ids(List<dynamic> l) => [for (final s in l) s.id as String];

  test('sorts case-insensitively, both directions, nulls as zero', () {
    expect(ids(sortSongs(songs, SortOption.titleAsc)), ['2', '1', '3']);
    expect(ids(sortSongs(songs, SortOption.titleDesc)), ['3', '1', '2']);
    expect(ids(sortSongs(songs, SortOption.artistAsc)), ['2', '3', '1']);
    expect(ids(sortSongs(songs, SortOption.durationAsc)), ['3', '2', '1']);
  });

  test('filters by artist and album', () {
    expect(ids(filterSongs(songs, artist: 'Bob')), ['3']);
    expect(ids(filterSongs(songs, album: 'X')), ['2']);
    expect(ids(filterSongs(songs)), ['1', '2', '3']);
  });

  test('search matches title, artist or album; blank query finds nothing', () {
    expect(ids(searchSongs(songs, 'ALP')), ['2']);
    expect(ids(searchSongs(songs, 'bob')), ['3']);
    expect(ids(searchSongs(songs, 'y')), ['3']);
    expect(searchSongs(songs, '  '), isEmpty);
  });

  test('groups by parent directory, folders sorted by name', () {
    final folders = groupByFolder(songs);
    expect([for (final f in folders) f.name], ['music', 'Rock']);
    expect(ids(folders.last.songs), ['1', '3']);
    expect(folders.last.path, '/m/Rock');
  });

  test(
    'groups search into artists, albums and songs, prefix matches first',
    () {
      final library = [
        _song('1', title: 'Rain', artist: 'Brainstorm', album: 'Rainy days'),
        _song('2', title: 'Sun', artist: 'Rainbow', album: 'Rainbow'),
        _song('3', title: 'Moon', artist: 'Rainbow'),
      ];
      final r = searchLibrary(library, 'rain');
      expect(r.artists, ['Rainbow', 'Brainstorm']);
      expect(r.albums, ['Rainbow', 'Rainy days']);
      expect(ids(r.songs), ['1', '2', '3']);
      expect(searchLibrary(library, '  ').artists, isEmpty);
    },
  );

  test('WhatsApp audios are recognised by name or folder', () {
    expect(
      isChatAudio(_song('AUD-20260701-WA0006', title: 'AUD-20260701-WA0006')),
      isTrue,
    );
    expect(isChatAudio(_song('PTT-20250101-WA0001')), isTrue);
    expect(
      isChatAudio(
        _song(
          'x',
          dir: '/sdcard/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio',
        ),
      ),
      isTrue,
    );
    expect(isChatAudio(_song('Audio Track', title: 'AUD me')), isFalse);
  });
}
