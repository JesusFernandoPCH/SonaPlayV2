import 'package:flutter/foundation.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/songs_persistence_datasource.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/settings/data/datasources/settings_local_datasource.dart';

/// Datasource for local music files (MediaStore + Hive cache)
class LocalMusicDataSource {
  final MediaStoreDataSource _mediaStore = MediaStoreDataSource();
  final SongsPersistenceDataSource _persistence = SongsPersistenceDataSource();

  /// Query all songs from device (Optimized with Streams)
  Stream<List<SongModel>> getAllSongs() async* {
    // 1. Try to get from local cache (Hive) for instant UI
    final cachedSongs = await _persistence.getCachedSongs();

    if (cachedSongs.isNotEmpty) {
      yield cachedSongs;
    }

    // 2. Perform background sync and yield updated results
    yield* _backgroundScanAndSyncStream();
  }

  /// Perform scanning and metadata extraction in background as a Stream
  Stream<List<SongModel>> _backgroundScanAndSyncStream() async* {
    try {
      // The native side queries MediaStore off the UI thread, sorted by title
      final mappedSongs = await _mediaStore.querySongs();

      // Filter by min duration from settings
      final settings = SettingsLocalDataSource();
      final minDuration = settings.minDuration; // in seconds

      final filteredSongs = mappedSongs.where((song) {
        final durationInSeconds = (song.duration ?? 0) / 1000;
        return durationInSeconds >= minDuration;
      }).toList();

      // Save to persistence
      await _persistence.saveSongs(filteredSongs);

      yield filteredSongs;
    } catch (e) {
      debugPrint('Error during background scan: $e');
    }
  }

  /// Query songs by artist (Non-streaming for specific queries)
  Future<List<SongModel>> getSongsByArtist(String artist) async {
    final box = await _persistence.getCachedSongs();
    return box.where((song) => song.artist == artist).toList();
  }

  /// Query songs by album (Non-streaming for specific queries)
  Future<List<SongModel>> getSongsByAlbum(String album) async {
    final box = await _persistence.getCachedSongs();
    return box.where((song) => song.album == album).toList();
  }
}
