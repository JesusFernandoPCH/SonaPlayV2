import 'package:hive_ce_flutter/hive_flutter.dart';

class SettingsLocalDataSource {
  static const String boxName = 'settings_box';

  static const String kMinDuration = 'min_duration';

  Box get _box => Hive.box(boxName);

  /// Songs shorter than this (seconds) are left out of the library
  int get minDuration => _box.get(kMinDuration, defaultValue: 30);

  Future<void> setMinDuration(int value) => _box.put(kMinDuration, value);
}
