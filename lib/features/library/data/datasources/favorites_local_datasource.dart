import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/data/models/favorite_model.dart';

/// Local datasource for managing favorites using Hive
class FavoritesLocalDataSource {
  static const String _boxName = 'favorites';
  Box<FavoriteModel>? _box;

  /// Get the favorites box (lazy initialization)
  Future<Box<FavoriteModel>> get _favoritesBox async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<FavoriteModel>(_boxName);
    }
    return _box!;
  }

  /// Check if a song is favorited
  Future<bool> isFavorite(String songId) async {
    final box = await _favoritesBox;
    return box.containsKey(songId);
  }

  /// Add a song to favorites
  Future<void> addFavorite(String songId) async {
    final box = await _favoritesBox;
    final favorite = FavoriteModel.fromSongId(songId);
    await box.put(songId, favorite);
  }

  /// Remove a song from favorites
  Future<void> removeFavorite(String songId) async {
    final box = await _favoritesBox;
    await box.delete(songId);
  }

  /// Get all favorite song IDs
  Future<List<String>> getAllFavorites() async {
    final box = await _favoritesBox;
    return box.keys.cast<String>().toList();
  }

  /// Emits the favorite song IDs now and after every change
  Stream<Set<String>> watchFavoriteIds() async* {
    final box = await _favoritesBox;
    yield box.keys.cast<String>().toSet();
    yield* box.watch().map((_) => box.keys.cast<String>().toSet());
  }

  /// Get all favorites with timestamps (sorted by most recent)
  Future<List<FavoriteModel>> getAllFavoritesWithTimestamps() async {
    final box = await _favoritesBox;
    final favorites = box.values.toList();
    favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return favorites;
  }

  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    final box = await _favoritesBox;
    await box.clear();
  }

  /// Get favorites count
  Future<int> getFavoritesCount() async {
    final box = await _favoritesBox;
    return box.length;
  }
}
