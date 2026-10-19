import 'package:hive_ce/hive.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:sonaplay/features/library/domain/entities/song.dart';

part 'song_model.g.dart';

/// Data model for Song (maps from on_audio_query)
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

  /// Create from on_audio_query SongModel
  factory SongModel.fromAudioQuery(audio_query.SongModel audioSong) {
    return SongModel(
      id: audioSong.id.toString(),
      title: audioSong.title,
      artist: audioSong.artist ?? 'Unknown Artist',
      album: audioSong.album,
      albumId: audioSong.albumId?.toString(),
      duration: audioSong.duration,
      dateAdded: audioSong.dateAdded,
      artworkPath: null, // Will be queried separately if needed
      filePath: audioSong.data,
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
