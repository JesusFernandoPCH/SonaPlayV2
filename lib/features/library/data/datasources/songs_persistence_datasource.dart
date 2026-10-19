import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';

/// Datasource for persisting song metadata locally using Hive
class SongsPersistenceDataSource {
  static const String boxName = 'cached_songs';

  /// Save songs to Hive box
  Future<void> saveSongs(List<SongModel> songs) async {
    final box = await Hive.openBox<SongModel>(boxName);
    // Clear old data and save new
    await box.clear();
    final Map<String, SongModel> songMap = {
      for (var song in songs) song.id: song,
    };
    await box.putAll(songMap);
  }

  /// Get cached songs from Hive box
  Future<List<SongModel>> getCachedSongs() async {
    final box = await Hive.openBox<SongModel>(boxName);
    return box.values.toList();
  }

  /// Remove specific songs from the cache
  Future<void> removeSongs(Iterable<String> songIds) async {
    final box = await Hive.openBox<SongModel>(boxName);
    await box.deleteAll(songIds);
  }

  /// Check if cache is empty
  Future<bool> isCacheEmpty() async {
    final box = await Hive.openBox<SongModel>(boxName);
    return box.isEmpty;
  }

  /// Clear all cached songs
  Future<void> clearCache() async {
    final box = await Hive.openBox<SongModel>(boxName);
    await box.clear();
  }
}
