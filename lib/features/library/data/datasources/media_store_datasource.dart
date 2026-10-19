import 'package:flutter/services.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';

/// Device music through the native "sonaplay/media" channel (Android MediaStore)
class MediaStoreDataSource {
  static const _channel = MethodChannel('sonaplay/media');

  Future<List<SongModel>> querySongs() async {
    final rows = await _channel.invokeListMethod<Map>('querySongs') ?? [];
    return rows
        .map((row) => SongModel.fromMediaStore(row.cast<String, Object?>()))
        .toList();
  }

  /// JPEG bytes of the embedded artwork, or null when the song has none
  Future<Uint8List?> artwork(String songId, {int size = 300}) =>
      _channel.invokeMethod<Uint8List>('artwork', {
        'id': int.parse(songId),
        'size': size,
      });

  /// Deletes the files for real; returns the IDs the system actually removed
  /// (the user can cancel the confirmation dialog)
  Future<List<String>> deleteSongs(List<String> songIds) async =>
      await _channel.invokeListMethod<String>('deleteSongs', {
        'ids': songIds.map(int.parse).toList(),
      }) ??
      [];
}
