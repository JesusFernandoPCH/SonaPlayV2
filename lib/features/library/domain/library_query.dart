import 'package:sonaplay/features/library/domain/entities/folder.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';

/// Pure list operations behind the library screens (sort, filter, search, folders)

final _chatAudioName = RegExp(r'^(AUD|PTT)-\d{8}-WA\d+', caseSensitive: false);

/// WhatsApp voice notes and audios ("AUD-20260701-WA0006"), which aren't music
bool isChatAudio(Song song) {
  final path = song.filePath.toLowerCase();
  final name = path.substring(path.lastIndexOf('/') + 1);
  return path.contains('/com.whatsapp/') ||
      _chatAudioName.hasMatch(song.title) ||
      _chatAudioName.hasMatch(name);
}

List<Song> sortSongs(List<Song> songs, SortOption option) {
  int text(String? a, String? b) =>
      (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());
  final int Function(Song, Song) compare = switch (option) {
    SortOption.titleAsc ||
    SortOption.titleDesc => (a, b) => text(a.title, b.title),
    SortOption.artistAsc ||
    SortOption.artistDesc => (a, b) => text(a.artist, b.artist),
    SortOption.albumAsc ||
    SortOption.albumDesc => (a, b) => text(a.album, b.album),
    SortOption.durationAsc || SortOption.durationDesc => (
      a,
      b,
    ) => (a.duration ?? 0).compareTo(b.duration ?? 0),
    SortOption.dateAddedAsc || SortOption.dateAddedDesc => (
      a,
      b,
    ) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0),
  };
  final descending = option.name.endsWith('Desc');
  return [...songs]..sort(descending ? (a, b) => compare(b, a) : compare);
}

List<Song> filterSongs(List<Song> songs, {String? artist, String? album}) =>
    songs
        .where(
          (s) =>
              (artist == null || s.artist == artist) &&
              (album == null || s.album == album),
        )
        .toList();

/// Case-insensitive match on title, artist or album
List<Song> searchSongs(List<Song> songs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return songs
      .where(
        (s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            (s.album?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

/// Songs grouped by the directory that holds the file, folders sorted by name
List<Folder> groupByFolder(List<Song> songs) {
  final byPath = <String, List<Song>>{};
  for (final song in songs) {
    final cut = song.filePath.lastIndexOf('/');
    final path = cut > 0 ? song.filePath.substring(0, cut) : '/';
    byPath.putIfAbsent(path, () => []).add(song);
  }
  return [
    for (final MapEntry(key: path, value: folderSongs) in byPath.entries)
      Folder(
        path: path,
        name: path.substring(path.lastIndexOf('/') + 1),
        songs: folderSongs,
      ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

typedef SearchResults = ({
  List<String> artists,
  List<String> albums,
  List<Song> songs,
});

/// Search grouped like a music app: artists and albums whose name matches
/// (those starting with the query first), then the matching songs
SearchResults searchLibrary(List<Song> songs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return (artists: const [], albums: const [], songs: const []);

  List<String> names(Iterable<String?> values) {
    final matching = {
      for (final v in values)
        if (v != null && v.isNotEmpty && v.toLowerCase().contains(q)) v,
    }.toList();
    int rank(String v) => v.toLowerCase().startsWith(q) ? 0 : 1;
    return matching..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.toLowerCase().compareTo(b.toLowerCase());
    });
  }

  return (
    artists: names(songs.map((s) => s.artist)),
    albums: names(songs.map((s) => s.album)),
    songs: searchSongs(songs, query),
  );
}
