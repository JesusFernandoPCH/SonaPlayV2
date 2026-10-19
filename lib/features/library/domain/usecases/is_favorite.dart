import 'package:sonaplay/features/library/domain/repositories/favorites_repository.dart';

/// Use case for checking if a song is favorited
class IsFavorite {
  final FavoritesRepository _repository;

  IsFavorite(this._repository);

  Future<bool> call(String songId) async {
    return await _repository.isFavorite(songId);
  }
}
