import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/local_music_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/metadata_persistence_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/data/repositories/library_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/folder.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';
import 'package:sonaplay/features/library/domain/library_query.dart';
import 'package:sonaplay/features/player/data/datasources/playback_persistence_datasource.dart';

/// All device songs: cached list first, then the fresh MediaStore scan
final songsProvider = StreamProvider<List<Song>>((ref) {
  return LibraryRepositoryImpl(
    LocalMusicDataSource(),
    MetadataPersistenceDataSource(),
  ).getAllSongs();
});

final favoritesDataSourceProvider = Provider(
  (ref) => FavoritesLocalDataSource(),
);

final favoriteIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(favoritesDataSourceProvider).watchFavoriteIds();
});

final trashIdsProvider = StreamProvider<List<String>>((ref) {
  return DeletedSongsLocalDataSource().watchDeletedSongs();
});

final hiddenIdsProvider = StreamProvider<List<String>>((ref) {
  return HiddenSongsLocalDataSource().watchHiddenSongIds();
});

final playlistsDataSourceProvider = Provider(
  (ref) => PlaylistsLocalDataSource(),
);

final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(playlistsDataSourceProvider).watchPlaylists();
});

/// Library songs without the hidden ones and the ones in the trash
final visibleSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final excluded = {
    ...?ref.watch(hiddenIdsProvider).value,
    ...?ref.watch(trashIdsProvider).value,
  };
  return ref
      .watch(songsProvider)
      .whenData(
        (songs) => [
          for (final s in songs)
            if (!excluded.contains(s.id) && !isChatAudio(s)) s,
        ],
      );
});

// ========== Sort and filters (remembered across restarts) ==========

final sortOptionProvider = NotifierProvider<SortNotifier, SortOption>(
  SortNotifier.new,
);

class SortNotifier extends Notifier<SortOption> {
  final _store = PlaybackPersistenceDataSource();

  @override
  SortOption build() => _store.sortOption;

  void select(SortOption option) {
    state = option;
    _store.setSortOption(option);
  }
}

/// How song lists are laid out: small rows, normal rows or artwork cards
enum LibraryView { compact, normal, grid }

final libraryViewProvider = NotifierProvider<LibraryViewNotifier, LibraryView>(
  LibraryViewNotifier.new,
);

class LibraryViewNotifier extends Notifier<LibraryView> {
  static const _key = 'library_view';
  Box get _box => Hive.box('settings_box');

  @override
  LibraryView build() {
    final i = _box.get(_key, defaultValue: LibraryView.normal.index) as int;
    return LibraryView.values[i.clamp(0, LibraryView.values.length - 1)];
  }

  void select(LibraryView view) {
    state = view;
    _box.put(_key, view.index);
  }
}

// ========== Lists behind each tab ==========

/// "Canciones" tab: visible songs, sorted
final librarySongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final sort = ref.watch(sortOptionProvider);
  return ref
      .watch(visibleSongsProvider)
      .whenData((songs) => sortSongs(songs, sort));
});

final favoriteSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final favorites = ref.watch(favoriteIdsProvider).value ?? const {};
  final sort = ref.watch(sortOptionProvider);
  return ref
      .watch(visibleSongsProvider)
      .whenData(
        (songs) => sortSongs(
          songs.where((s) => favorites.contains(s.id)).toList(),
          sort,
        ),
      );
});

final foldersProvider = Provider<AsyncValue<List<Folder>>>((ref) {
  return ref.watch(visibleSongsProvider).whenData(groupByFolder);
});

/// Songs of a playlist (by ID) in playlist order, skipping ones no longer visible.
/// Keyed by ID because Playlist.== only compares the song count.
final playlistSongsProvider = Provider.family<List<Song>, String>((
  ref,
  playlistId,
) {
  final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
  final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
  if (playlist == null) return const [];
  final byId = {
    for (final s in ref.watch(visibleSongsProvider).value ?? const <Song>[])
      s.id: s,
  };
  return [for (final id in playlist.songIds) ?byId[id]];
});
