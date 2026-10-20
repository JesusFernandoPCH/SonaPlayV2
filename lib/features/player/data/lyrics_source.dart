import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';

/// Finds the lyrics of a song: a copy kept by the app, the .lrc file next to
/// the song (Snaptube and others save one), or LRCLIB online. Returns raw LRC
/// or plain text; null when there are none.
class LyricsSource {
  static const _none = '';

  Future<File> _cached(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/lyrics/${song.id}.lrc');
  }

  Future<String?> load(Song song) async {
    final cached = await _cached(song);
    if (await cached.exists()) {
      final text = await cached.readAsString();
      return text == _none ? null : text;
    }

    final sidecar = File(
      song.filePath.replaceFirst(RegExp(r'\.[^./]+$'), '.lrc'),
    );
    try {
      if (await sidecar.exists()) return await sidecar.readAsString();
    } on FileSystemException {
      // Not readable with the audio permission alone; go online
    }

    final online = await _lrclib(song);
    // Offline or server error (null): try again next time
    if (online == null) return null;
    await cached.parent.create(recursive: true);
    await cached.writeAsString(online);
    return online == _none ? null : online;
  }

  /// Saves lyrics written or pasted by the user
  Future<void> save(Song song, String text) async {
    final cached = await _cached(song);
    await cached.parent.create(recursive: true);
    await cached.writeAsString(text);
  }

  /// Synced lyrics if any match, else plain ones; [_none] when nothing
  /// matched, null when the search failed
  Future<String?> _lrclib(Song song) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {
        'q': searchQuery(song),
      });
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'SonaPlay (https://github.com/JesusFernandoPCH/SonaPlayV2)',
      );
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final results = (jsonDecode(
        await response.transform(utf8.decoder).join(),
      ) as List).cast<Map<String, dynamic>>();

      final seconds = (song.duration ?? 0) / 1000;
      bool close(Map<String, dynamic> r) =>
          ((r['duration'] as num? ?? 0) - seconds).abs() < 5;
      final synced = results.where((r) => r['syncedLyrics'] != null);
      final best =
          synced.where(close).firstOrNull ??
          synced.firstOrNull ??
          results.where((r) => r['plainLyrics'] != null).firstOrNull;
      return (best?['syncedLyrics'] ?? best?['plainLyrics'] ?? _none) as String;
    } on Object {
      return null;
    } finally {
      client.close();
    }
  }
}

/// "Aqua - Barbie Girl (Official Music Video)" by "AquaVEVO" -> "Aqua -
/// Barbie Girl"; titles without the artist get it from the tag
String searchQuery(Song song) {
  String clean(String s) => s
      .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]|【[^】]*】'), ' ')
      .replaceAll(RegExp(r'- topic$', caseSensitive: false), ' ')
      .replaceAll(
        RegExp(
          r'\b(official|video|audio|lyrics?|letra|hd|4k)\b|vevo\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final title = clean(song.title);
  if (title.contains(' - ')) return title;
  final artist = clean(song.artist);
  return artist.isEmpty || artist.toLowerCase().contains('unknown')
      ? title
      : '$artist $title';
}
