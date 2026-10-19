import 'package:sonaplay/features/library/domain/repositories/favorites_repository.dart';

/// Use case for getting all favorite song IDs
class GetFavorites {
  final FavoritesRepository _repository;

  GetFavorites(this._repository);

  Future<List<String>> call() async {
    return await _repository.getAllFavorites();
  }
}
