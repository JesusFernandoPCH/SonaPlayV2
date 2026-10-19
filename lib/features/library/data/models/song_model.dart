import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';

part 'song_model.g.dart';

/// Data model for Song (maps from Android MediaStore)
@HiveType(typeId: 4)
class SongModel extends Song {
  @override
  @HiveField(0)
  final String id;

  @override
  @HiveField(1)
  final String title;

  @override
  @HiveField(2)
  final String artist;

  @override
  @HiveField(3)
  final String? album;

  @override
  @HiveField(4)
  final String? albumId;

  @override
  @HiveField(5)
  final int? duration;

  @override
  @HiveField(6)
  final int? dateAdded;

  @override
  @HiveField(7)
  final String? artworkPath;

  @override
  @HiveField(8)
  final String filePath;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumId,
    this.duration,
    this.dateAdded,
    this.artworkPath,
    required this.filePath,
  });

  /// Create from a row of the native "sonaplay/media" channel
  factory SongModel.fromMediaStore(Map<String, Object?> row) {
    return SongModel(
      id: '${row['id']}',
      title: row['title'] as String,
      artist: row['artist'] as String? ?? 'Unknown Artist',
      album: row['album'] as String?,
      albumId: row['albumId']?.toString(),
      duration: row['duration'] as int?,
      dateAdded: row['dateAdded'] as int?,
      artworkPath:
          null, // Queried separately through MediaStoreDataSource.artwork
      filePath: row['path'] as String,
    );
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumId,
    int? duration,
    int? dateAdded,
    String? artworkPath,
    String? filePath,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      artworkPath: artworkPath ?? this.artworkPath,
      filePath: filePath ?? this.filePath,
    );
  }
}
