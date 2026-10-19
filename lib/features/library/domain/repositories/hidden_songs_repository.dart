/// Repository interface for hidden songs
abstract class HiddenSongsRepository {
  /// Get list of hidden song IDs
  Future<List<String>> getHiddenSongIds();

  /// Hide a song
  Future<void> hideSong(String songId);

  /// Unhide a song
  Future<void> unhideSong(String songId);

  /// Check if a song is hidden
  Future<bool> isSongHidden(String songId);

  /// Stream of hidden song IDs
  Stream<List<String>> watchHiddenSongIds();
}
