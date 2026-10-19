import 'package:hive_ce/hive.dart';

part 'favorite_model.g.dart';

/// Hive model for storing favorite songs
/// TypeId 0 is reserved for FavoriteModel
@HiveType(typeId: 0)
class FavoriteModel extends HiveObject {
  @HiveField(0)
  final String songId;

  @HiveField(1)
  final DateTime addedAt;

  FavoriteModel({required this.songId, required this.addedAt});

  /// Create from song ID (auto-generates timestamp)
  factory FavoriteModel.fromSongId(String songId) {
    return FavoriteModel(songId: songId, addedAt: DateTime.now());
  }

  @override
  String toString() => 'FavoriteModel(songId: $songId, addedAt: $addedAt)';
}
