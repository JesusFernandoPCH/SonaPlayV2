import 'package:sonaplay/features/library/domain/repositories/hidden_songs_repository.dart';

/// Use case to unhide a song
class UnhideSong {
  final HiddenSongsRepository repository;

  UnhideSong(this.repository);

  Future<void> call(String songId) {
    return repository.unhideSong(songId);
  }
}
