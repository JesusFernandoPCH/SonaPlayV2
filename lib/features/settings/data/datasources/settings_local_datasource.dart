import 'package:hive_ce_flutter/hive_flutter.dart';

class SettingsLocalDataSource {
  static const String boxName = 'settings_box';

  static const String kMinDuration = 'min_duration';
  static const String kEqualizerEnabled = 'eq_enabled';
  static const String kEqualizerGains = 'eq_gains';

  Box get _box => Hive.box(boxName);

  /// Songs shorter than this (seconds) are left out of the library
  int get minDuration => _box.get(kMinDuration, defaultValue: 30);

  Future<void> setMinDuration(int value) => _box.put(kMinDuration, value);

  bool get equalizerEnabled => _box.get(kEqualizerEnabled, defaultValue: false);

  /// Gain in dB per band, in the order the device reports its bands
  List<double> get equalizerGains =>
      List<double>.from(_box.get(kEqualizerGains, defaultValue: const []));

  Future<void> setEqualizerEnabled(bool value) =>
      _box.put(kEqualizerEnabled, value);

  Future<void> setEqualizerGains(List<double> gains) =>
      _box.put(kEqualizerGains, gains);
}
