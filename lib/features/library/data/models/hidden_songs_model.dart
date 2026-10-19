import 'package:hive_ce/hive.dart';

part 'hidden_songs_model.g.dart';

/// Hive model for storing hidden song IDs
@HiveType(typeId: 3)
class HiddenSongsModel {
  @HiveField(0)
  final List<String> songIds;

  HiddenSongsModel({required this.songIds});

  /// Create empty model
  factory HiddenSongsModel.empty() {
    return HiddenSongsModel(songIds: []);
  }

  /// Copy with new song IDs
  HiddenSongsModel copyWith({List<String>? songIds}) {
    return HiddenSongsModel(songIds: songIds ?? this.songIds);
  }
}
