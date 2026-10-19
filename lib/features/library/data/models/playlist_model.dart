import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';

part 'playlist_model.g.dart';

/// Hive model for storing playlists
/// TypeId 1 is reserved for PlaylistModel
@HiveType(typeId: 1)
class PlaylistModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> songIds;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime? updatedAt;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to domain entity
  Playlist toEntity() {
    return Playlist(
      id: id,
      name: name,
      songIds: songIds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create from domain entity
  factory PlaylistModel.fromEntity(Playlist playlist) {
    return PlaylistModel(
      id: playlist.id,
      name: playlist.name,
      songIds: playlist.songIds,
      createdAt: playlist.createdAt,
      updatedAt: playlist.updatedAt,
    );
  }

  /// Create a copy with updated fields
  PlaylistModel copyWith({
    String? name,
    List<String>? songIds,
    DateTime? updatedAt,
  }) {
    return PlaylistModel(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'PlaylistModel(id: $id, name: $name, songCount: ${songIds.length})';
}
