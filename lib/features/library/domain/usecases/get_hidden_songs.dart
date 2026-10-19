import 'package:sonaplay/features/library/domain/repositories/hidden_songs_repository.dart';

/// Use case to get hidden songs
class GetHiddenSongs {
  final HiddenSongsRepository repository;

  GetHiddenSongs(this.repository);

  Future<List<String>> call() {
    return repository.getHiddenSongIds();
  }

  Stream<List<String>> watch() {
    return repository.watchHiddenSongIds();
  }
}
