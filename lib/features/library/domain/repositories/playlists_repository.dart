import 'package:sonaplay/features/library/domain/entities/playlist.dart';

/// Abstract repository for playlists
abstract class PlaylistsRepository {
  /// Create a new playlist
  Future<void> createPlaylist(Playlist playlist);

  /// Get a playlist by ID
  Future<Playlist?> getPlaylist(String id);

  /// Get all playlists
  Future<List<Playlist>> getAllPlaylists();

  /// Update a playlist
  Future<void> updatePlaylist(Playlist playlist);

  /// Delete a playlist
  Future<void> deletePlaylist(String id);

  /// Add a song to a playlist
  /// Returns true if song was added, false if it already exists (duplicate)
  Future<bool> addSongToPlaylist(String playlistId, String songId);

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId);

  /// Reorder songs in a playlist
  Future<void> reorderSongs(String playlistId, List<String> newSongIds);

  /// Clear all playlists
  Future<void> clearAllPlaylists();

  /// Get playlists count
  Future<int> getPlaylistsCount();
}
