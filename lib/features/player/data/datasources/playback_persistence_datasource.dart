import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';

class PlaybackPersistenceDataSource {
  static const String boxName = 'playback_settings_box';

  // Keys
  static const String kShuffleMode = 'shuffle_mode';
  static const String kRepeatMode = 'repeat_mode';
  static const String kSortOption = 'sort_option';

  Box get _box => Hive.box(boxName);

  // Playback Settings
  bool get shuffleMode => _box.get(kShuffleMode, defaultValue: false);
  RepeatMode get repeatMode {
    final modeName = _box.get(kRepeatMode, defaultValue: RepeatMode.all.name);
    return RepeatMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => RepeatMode.all,
    );
  }

  Future<void> setShuffleMode(bool value) => _box.put(kShuffleMode, value);
  Future<void> setRepeatMode(RepeatMode value) =>
      _box.put(kRepeatMode, value.name);

  // Sort
  SortOption get sortOption {
    final optionName = _box.get(
      kSortOption,
      defaultValue: SortOption.titleAsc.name,
    );
    return SortOption.values.firstWhere(
      (e) => e.name == optionName,
      orElse: () => SortOption.titleAsc,
    );
  }

  Future<void> setSortOption(SortOption value) =>
      _box.put(kSortOption, value.name);
}
