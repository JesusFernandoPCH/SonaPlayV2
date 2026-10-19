import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/domain/repositories/hidden_songs_repository.dart';

/// Implementation of HiddenSongsRepository
class HiddenSongsRepositoryImpl implements HiddenSongsRepository {
  final HiddenSongsLocalDataSource dataSource;

  HiddenSongsRepositoryImpl(this.dataSource);

  @override
  Future<List<String>> getHiddenSongIds() {
    return dataSource.getHiddenSongIds();
  }

  @override
  Future<void> hideSong(String songId) {
    return dataSource.hideSong(songId);
  }

  @override
  Future<void> unhideSong(String songId) {
    return dataSource.unhideSong(songId);
  }

  @override
  Future<bool> isSongHidden(String songId) {
    return dataSource.isSongHidden(songId);
  }

  @override
  Stream<List<String>> watchHiddenSongIds() {
    return dataSource.watchHiddenSongIds();
  }
}
