import 'package:sonaplay/features/library/domain/entities/song.dart';

/// Abstract repository for music library operations
abstract class LibraryRepository {
  /// Get all songs from device as a Stream for instant UI feedback
  Stream<List<Song>> getAllSongs();

  /// Get songs by artist
  Future<List<Song>> getSongsByArtist(String artist);

  /// Get songs by album
  Future<List<Song>> getSongsByAlbum(String album);

  /// Get song by ID
  Future<Song?> getSongById(String id);
}
