/// Abstract repository for favorites
abstract class FavoritesRepository {
  /// Check if a song is favorited
  Future<bool> isFavorite(String songId);

  /// Toggle favorite status (add if not favorite, remove if favorite)
  Future<void> toggleFavorite(String songId);

  /// Get all favorite song IDs
  Future<List<String>> getAllFavorites();

  /// Clear all favorites
  Future<void> clearAllFavorites();

  /// Get favorites count
  Future<int> getFavoritesCount();
}
