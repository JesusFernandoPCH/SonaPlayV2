import 'package:hive_ce/hive.dart';

/// Local data source for the in-app trash ("Recently Deleted") using Hive
class DeletedSongsLocalDataSource {
  static const String _boxName = 'deleted_songs';
  static const String _key = 'deleted_songs_ids';

  Future<Box> get _box => Hive.openBox(_boxName);

  List<String> _read(Box box) => List<String>.from(box.get(_key) ?? const []);

  Future<List<String>> getDeletedSongIds() async => _read(await _box);

  Future<void> softDeleteSong(String songId) async {
    final box = await _box;
    final current = _read(box);
    if (!current.contains(songId)) {
      await box.put(_key, current..add(songId));
    }
  }

  Future<void> restoreSong(String songId) => forget([songId]);

  /// Drops IDs from the trash (restored, or deleted from the device for good)
  Future<void> forget(Iterable<String> songIds) async {
    final box = await _box;
    final current = _read(box);
    final ids = songIds.toSet();
    if (current.any(ids.contains)) {
      await box.put(_key, current..removeWhere(ids.contains));
    }
  }

  /// Emits the current IDs, then again on every change
  Stream<List<String>> watchDeletedSongs() async* {
    final box = await _box;
    yield _read(box);
    yield* box.watch(key: _key).map((_) => _read(box));
  }
}
