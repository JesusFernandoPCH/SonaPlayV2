import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:sonaplay/features/library/data/datasources/songs_persistence_datasource.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/settings/data/datasources/settings_local_datasource.dart';

/// Datasource for local music files using on_audio_query
class LocalMusicDataSource {
  final audio_query.OnAudioQuery _audioQuery = audio_query.OnAudioQuery();
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
      final songs = await _audioQuery.querySongs(
        sortType: audio_query.SongSortType.TITLE,
        orderType: audio_query.OrderType.ASC_OR_SMALLER,
        uriType: audio_query.UriType.EXTERNAL,
      );

      // Extract metadata in background isolate to avoid UI jank
      final List<SongModel> mappedSongs = await compute(
        _parseSongsInIsolate,
        songs,
      );

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

/// Helper function for compute (must be top-level or static)
List<SongModel> _parseSongsInIsolate(List<audio_query.SongModel> audioSongs) {
  return audioSongs.map((song) => SongModel.fromAudioQuery(song)).toList();
}
