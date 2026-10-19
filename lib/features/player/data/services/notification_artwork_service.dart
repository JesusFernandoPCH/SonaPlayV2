import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';

/// Service to handle artwork extraction and caching for system notifications.
///
/// This service ensures that the system notification area can display high-quality
/// artwork for the currently playing song by providing a valid URI.
class NotificationArtworkService {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  static const String _folderName = 'notification_art';

  /// Returns a valid URI for the song's artwork.
  ///
  /// Extracts the artwork using [on_audio_query] and caches it in a temporary
  /// directory to provide a valid 'file://' URI for the system notification.
  Future<Uri?> getArtworkUri(Song song) async {
    // 1. Manually extract and cache the artwork.
    // We avoid 'content://' URIs as they often lead to permission issues
    // in the system notification area on modern Android versions.
    try {
      final tempDir = await getTemporaryDirectory();
      final artDir = Directory('${tempDir.path}/$_folderName');

      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }

      final fileName = 'song_${song.id}_thumb.jpg';
      final file = File('${artDir.path}/$fileName');

      // Check if already in cache to avoid redundant extraction
      if (await file.exists()) {
        return file.uri;
      }

      // Query bytes from on_audio_query
      final bytes = await _audioQuery.queryArtwork(
        int.parse(song.id),
        ArtworkType.AUDIO,
        size: 500, // Sufficient for notification display
        quality: 100,
        format: ArtworkFormat.JPEG,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await file.writeAsBytes(bytes);
        return file.uri;
      }
    } catch (e) {
      // Log error but don't crash, the notification will just use the default icon
      debugPrint('Error getting notification artwork: $e');
    }

    return null;
  }

  /// Clean up cached artwork to free space.
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final artDir = Directory('${tempDir.path}/$_folderName');
      if (await artDir.exists()) {
        await artDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Simple debugPrint helper for the service
void debugPrint(String message) {
  // ignore: avoid_print
  print('[NotificationArtworkService] $message');
}
