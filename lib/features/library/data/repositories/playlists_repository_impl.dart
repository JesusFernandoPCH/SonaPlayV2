import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/repositories/playlists_repository.dart';

/// Implementation of PlaylistsRepository using local datasource
class PlaylistsRepositoryImpl implements PlaylistsRepository {
  final PlaylistsLocalDataSource _localDataSource;

  PlaylistsRepositoryImpl(this._localDataSource);

  @override
  Future<void> createPlaylist(Playlist playlist) async {
    await _localDataSource.createPlaylist(playlist);
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    return await _localDataSource.getPlaylist(id);
  }

  @override
  Future<List<Playlist>> getAllPlaylists() async {
    return await _localDataSource.getAllPlaylists();
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    await _localDataSource.updatePlaylist(playlist);
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _localDataSource.deletePlaylist(id);
  }

  @override
  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    return await _localDataSource.addSongToPlaylist(playlistId, songId);
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _localDataSource.removeSongFromPlaylist(playlistId, songId);
  }

  @override
  Future<void> reorderSongs(String playlistId, List<String> newSongIds) async {
    await _localDataSource.reorderSongs(playlistId, newSongIds);
  }

  @override
  Future<void> clearAllPlaylists() async {
    await _localDataSource.clearAllPlaylists();
  }

  @override
  Future<int> getPlaylistsCount() async {
    return await _localDataSource.getPlaylistsCount();
  }
}
