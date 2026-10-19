import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/domain/repositories/library_repository.dart';

/// Use case to get all songs from the library
class GetAllSongs {
  final LibraryRepository repository;

  GetAllSongs(this.repository);

  Stream<List<Song>> call() {
    return repository.getAllSongs();
  }
}
