/// Domain entity for Playlist
class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a copy with updated fields
  Playlist copyWith({
    String? name,
    List<String>? songIds,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Playlist &&
        other.id == id &&
        other.name == name &&
        other.songIds.length == songIds.length &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        songIds.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() =>
      'Playlist(id: $id, name: $name, songCount: ${songIds.length})';
}
