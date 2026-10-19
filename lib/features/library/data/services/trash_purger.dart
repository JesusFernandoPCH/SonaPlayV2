import 'package:permission_handler/permission_handler.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/songs_persistence_datasource.dart';

/// "Delete permanently" from the in-app trash: removes the files from the device,
/// then every local reference to them (trash, favorites, hidden, playlists, cache).
class TrashPurger {
  final MediaStoreDataSource _mediaStore;
  final DeletedSongsLocalDataSource _trash;
  final FavoritesLocalDataSource _favorites;
  final HiddenSongsLocalDataSource _hidden;
  final PlaylistsLocalDataSource _playlists;
  final SongsPersistenceDataSource _cache;
  final Future<void> Function() _ensureWriteAccess;

  TrashPurger({
    MediaStoreDataSource? mediaStore,
    DeletedSongsLocalDataSource? trash,
    FavoritesLocalDataSource? favorites,
    HiddenSongsLocalDataSource? hidden,
    PlaylistsLocalDataSource? playlists,
    SongsPersistenceDataSource? cache,
    Future<void> Function()? ensureWriteAccess,
  }) : _mediaStore = mediaStore ?? MediaStoreDataSource(),
       _trash = trash ?? DeletedSongsLocalDataSource(),
       _favorites = favorites ?? FavoritesLocalDataSource(),
       _hidden = hidden ?? HiddenSongsLocalDataSource(),
       _playlists = playlists ?? PlaylistsLocalDataSource(),
       _cache = cache ?? SongsPersistenceDataSource(),
       _ensureWriteAccess = ensureWriteAccess ?? _requestLegacyWrite;

  /// Returns the IDs really deleted; the rest stay in the trash
  /// (e.g. the user cancelled the system confirmation)
  /// (the caller also removes them from the player queue)
  Future<List<String>> purge(List<String> songIds) async {
    if (songIds.isEmpty) return [];
    await _ensureWriteAccess();
    final deleted = await _mediaStore.deleteSongs(songIds);
    if (deleted.isEmpty) return deleted;

    await _trash.forget(deleted);
    await _cache.removeSongs(deleted);
    for (final id in deleted) {
      await _favorites.removeFavorite(id);
      await _hidden.unhideSong(id);
    }
    for (final playlist in await _playlists.getAllPlaylists()) {
      for (final id in playlist.songIds.where(deleted.contains)) {
        await _playlists.removeSongFromPlaylist(playlist.id, id);
      }
    }
    return deleted;
  }
}

/// Android 9 and below delete files directly and need WRITE_EXTERNAL_STORAGE;
/// on newer versions this resolves without showing anything.
Future<void> _requestLegacyWrite() async {
  await Permission.storage.request();
}
