import 'package:hive_ce_flutter/hive_flutter.dart';

/// Datasource for persisting metadata overrides (Title, Artist, Album, Artwork)
/// These overrides are local to the app and do not modify the actual files.
class MetadataPersistenceDataSource {
  static const String boxName = 'metadata_overrides';

  /// Save override for a specific song
  Future<void> saveOverride({
    required String songId,
    String? title,
    String? artist,
    String? album,
    String? artworkPath,
  }) async {
    final box = await Hive.openBox(boxName);
    final currentData = box.get(songId) as Map? ?? {};

    final newData = Map<String, dynamic>.from(currentData);
    if (title != null) newData['title'] = title;
    if (artist != null) newData['artist'] = artist;
    if (album != null) newData['album'] = album;
    if (artworkPath != null) newData['artworkPath'] = artworkPath;

    await box.put(songId, newData);
  }

  /// Get override for a specific song
  Future<Map<String, dynamic>?> getOverride(String songId) async {
    final box = await Hive.openBox(boxName);
    final data = box.get(songId);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Get all overrides
  Future<Map<String, Map<String, dynamic>>> getAllOverrides() async {
    final box = await Hive.openBox(boxName);
    final Map<String, Map<String, dynamic>> allOverrides = {};
    for (var key in box.keys) {
      final value = box.get(key);
      if (value is Map) {
        allOverrides[key.toString()] = Map<String, dynamic>.from(value);
      }
    }
    return allOverrides;
  }

  /// Clear all overrides
  Future<void> clearAll() async {
    final box = await Hive.openBox(boxName);
    await box.clear();
  }
}
