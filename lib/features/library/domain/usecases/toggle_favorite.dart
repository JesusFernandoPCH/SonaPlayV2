import 'package:sonaplay/features/library/domain/repositories/favorites_repository.dart';

/// Use case for toggling a song's favorite status
class ToggleFavorite {
  final FavoritesRepository _repository;

  ToggleFavorite(this._repository);

  Future<void> call(String songId) async {
    await _repository.toggleFavorite(songId);
  }
}
