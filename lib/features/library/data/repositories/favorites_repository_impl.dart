import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/domain/repositories/favorites_repository.dart';

/// Implementation of FavoritesRepository using local datasource
class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource _localDataSource;

  FavoritesRepositoryImpl(this._localDataSource);

  @override
  Future<bool> isFavorite(String songId) async {
    return await _localDataSource.isFavorite(songId);
  }

  @override
  Future<void> toggleFavorite(String songId) async {
    final isFav = await _localDataSource.isFavorite(songId);
    if (isFav) {
      await _localDataSource.removeFavorite(songId);
    } else {
      await _localDataSource.addFavorite(songId);
    }
  }

  @override
  Future<List<String>> getAllFavorites() async {
    return await _localDataSource.getAllFavorites();
  }

  @override
  Future<void> clearAllFavorites() async {
    await _localDataSource.clearAllFavorites();
  }

  @override
  Future<int> getFavoritesCount() async {
    return await _localDataSource.getFavoritesCount();
  }
}
