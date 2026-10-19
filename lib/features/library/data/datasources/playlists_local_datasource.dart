import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/data/models/playlist_model.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';

/// Local datasource for managing playlists using Hive
class PlaylistsLocalDataSource {
  static const String _boxName = 'playlists';
  Box<PlaylistModel>? _box;

  /// Get the playlists box (lazy initialization)
  Future<Box<PlaylistModel>> get _playlistsBox async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<PlaylistModel>(_boxName);
    }
    return _box!;
  }

  /// Create a new playlist
  Future<void> createPlaylist(Playlist playlist) async {
    final box = await _playlistsBox;
    final model = PlaylistModel.fromEntity(playlist);
    await box.put(playlist.id, model);
  }

  /// Get a playlist by ID
  Future<Playlist?> getPlaylist(String id) async {
    final box = await _playlistsBox;
    final model = box.get(id);
    return model?.toEntity();
  }

  /// Get all playlists (sorted by creation date, newest first)
  Future<List<Playlist>> getAllPlaylists() async {
    final box = await _playlistsBox;
    final models = box.values.toList();
    models.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return models.map((model) => model.toEntity()).toList();
  }

  /// Emits all playlists (newest first) now and after every change
  Stream<List<Playlist>> watchPlaylists() async* {
    final box = await _playlistsBox;
    yield await getAllPlaylists();
    await for (final _ in box.watch()) {
      yield await getAllPlaylists();
    }
  }

  /// Update a playlist
  Future<void> updatePlaylist(Playlist playlist) async {
    final box = await _playlistsBox;
    final model = PlaylistModel.fromEntity(playlist);
    await box.put(playlist.id, model);
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String id) async {
    final box = await _playlistsBox;
    await box.delete(id);
  }

  /// Add a song to a playlist
  /// Returns true if song was added, false if it already exists (duplicate)
  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    final box = await _playlistsBox;
    final model = box.get(playlistId);
    if (model != null) {
      // Check for duplicates
      if (model.songIds.contains(songId)) {
        return false; // Indicate duplicate
      }

      final updatedSongIds = List<String>.from(model.songIds)..add(songId);
      final updatedModel = model.copyWith(
        songIds: updatedSongIds,
        updatedAt: DateTime.now(),
      );
      await box.put(playlistId, updatedModel);
      return true; // Indicate success
    }
    return false; // Playlist not found
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final box = await _playlistsBox;
    final model = box.get(playlistId);
    if (model != null) {
      final updatedSongIds = List<String>.from(model.songIds)..remove(songId);
      final updatedModel = model.copyWith(
        songIds: updatedSongIds,
        updatedAt: DateTime.now(),
      );
      await box.put(playlistId, updatedModel);
    }
  }

  /// Reorder songs in a playlist
  Future<void> reorderSongs(String playlistId, List<String> newSongIds) async {
    final box = await _playlistsBox;
    final model = box.get(playlistId);
    if (model != null) {
      final updatedModel = model.copyWith(
        songIds: newSongIds,
        updatedAt: DateTime.now(),
      );
      await box.put(playlistId, updatedModel);
    }
  }

  /// Clear all playlists
  Future<void> clearAllPlaylists() async {
    final box = await _playlistsBox;
    await box.clear();
  }

  /// Get playlists count
  Future<int> getPlaylistsCount() async {
    final box = await _playlistsBox;
    return box.length;
  }
}
