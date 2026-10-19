import 'package:sonaplay/features/library/domain/repositories/hidden_songs_repository.dart';

/// Use case to hide a song
class HideSong {
  final HiddenSongsRepository repository;

  HideSong(this.repository);

  Future<void> call(String songId) {
    return repository.hideSong(songId);
  }
}
