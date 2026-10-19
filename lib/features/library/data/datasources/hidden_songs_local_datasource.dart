import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/features/library/data/models/hidden_songs_model.dart';

/// Local data source for managing hidden songs
class HiddenSongsLocalDataSource {
  static const String _boxName = 'hidden_songs';
  static const String _key = 'hidden_song_ids';

  Future<Box<HiddenSongsModel>> get _box async =>
      await Hive.openBox<HiddenSongsModel>(_boxName);

  /// Get list of hidden song IDs
  Future<List<String>> getHiddenSongIds() async {
    final box = await _box;
    final model = box.get(_key);
    return model?.songIds ?? [];
  }

  /// Hide a song by adding its ID to the list
  Future<void> hideSong(String songId) async {
    final box = await _box;
    final model = box.get(_key) ?? HiddenSongsModel.empty();

    // Don't add if already hidden
    if (model.songIds.contains(songId)) {
      return;
    }

    final updatedIds = List<String>.from(model.songIds)..add(songId);
    final updatedModel = model.copyWith(songIds: updatedIds);
    await box.put(_key, updatedModel);
  }

  /// Unhide a song by removing its ID from the list
  Future<void> unhideSong(String songId) async {
    final box = await _box;
    final model = box.get(_key);

    if (model == null || !model.songIds.contains(songId)) {
      return;
    }

    final updatedIds = List<String>.from(model.songIds)..remove(songId);
    final updatedModel = model.copyWith(songIds: updatedIds);
    await box.put(_key, updatedModel);
  }

  /// Check if a song is hidden
  Future<bool> isSongHidden(String songId) async {
    final box = await _box;
    final model = box.get(_key);
    return model?.songIds.contains(songId) ?? false;
  }

  /// Stream of hidden song IDs
  Stream<List<String>> watchHiddenSongIds() async* {
    final box = await _box;

    // Emit initial value
    final initial = box.get(_key);
    yield initial?.songIds ?? [];

    // Watch for changes
    yield* box.watch(key: _key).map((event) {
      final model = event.value as HiddenSongsModel?;
      return model?.songIds ?? [];
    });
  }
}
