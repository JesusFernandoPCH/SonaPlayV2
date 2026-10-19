/// Domain entity representing a song
abstract class Song {
  String get id;
  String get title;
  String get artist;
  String? get album;
  String? get albumId;
  int? get duration; // in milliseconds
  int? get dateAdded; // timestamp
  String? get artworkPath;
  String get filePath;

  const Song();

  /// Format duration as MM:SS
  String get formattedDuration {
    if (duration == null) return '--:--';
    final seconds = duration! ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
