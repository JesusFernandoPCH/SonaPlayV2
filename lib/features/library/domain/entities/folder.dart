import 'package:sonaplay/features/library/domain/entities/song.dart';

/// Domain entity representing a folder containing music
class Folder {
  final String path;
  final String name;
  final List<Song> songs;

  const Folder({required this.path, required this.name, required this.songs});

  /// Get number of songs in this folder
  int get songCount => songs.length;

  /// Get total duration of all songs in this folder
  int get totalDuration {
    return songs.fold(0, (sum, song) => sum + (song.duration ?? 0));
  }
}
