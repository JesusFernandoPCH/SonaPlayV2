import 'package:sonaplay/features/library/data/datasources/local_music_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/metadata_persistence_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/domain/repositories/library_repository.dart';

/// Implementation of LibraryRepository
class LibraryRepositoryImpl implements LibraryRepository {
  final LocalMusicDataSource dataSource;
  final MetadataPersistenceDataSource metadataDataSource;

  LibraryRepositoryImpl(this.dataSource, this.metadataDataSource);

  @override
  Stream<List<Song>> getAllSongs() async* {
    await for (final songs in dataSource.getAllSongs()) {
      try {
        final overrides = await metadataDataSource.getAllOverrides();

        if (overrides.isEmpty) {
          yield songs.cast<Song>();
          continue;
        }

        final updatedSongs = songs.map((song) {
          final override = overrides[song.id];
          if (override != null) {
            return song.copyWith(
              title: override['title'] as String?,
              artist: override['artist'] as String?,
              album: override['album'] as String?,
              artworkPath: override['artworkPath'] as String?,
            );
          }
          return song as Song;
        }).toList();

        yield updatedSongs;
      } catch (e) {
        // Yield original songs if overrides fail
        yield songs.cast<Song>();
      }
    }
  }

  @override
  Future<List<Song>> getSongsByArtist(String artist) async {
    try {
      final songs = await dataSource.getSongsByArtist(artist);
      return songs.cast<Song>();
    } catch (e) {
      throw Exception('Failed to load songs by artist: $e');
    }
  }

  @override
  Future<List<Song>> getSongsByAlbum(String album) async {
    try {
      final songs = await dataSource.getSongsByAlbum(album);
      return songs.cast<Song>();
    } catch (e) {
      throw Exception('Failed to load songs by album: $e');
    }
  }

  @override
  Future<Song?> getSongById(String id) async {
    try {
      final allSongs = await getAllSongs().first;
      return allSongs.firstWhere((song) => song.id == id);
    } catch (e) {
      return null;
    }
  }
}
