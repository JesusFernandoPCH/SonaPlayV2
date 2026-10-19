import 'package:hive_ce_flutter/hive_flutter.dart';

class SettingsLocalDataSource {
  static const String boxName = 'settings_box';

  // Keys
  static const String kOledMode = 'oled_mode';
  static const String kGlassIntensity = 'glass_intensity';
  static const String kMinDuration = 'min_duration';
  static const String kArtworkQuality = 'artwork_quality';
  static const String kAccentColor = 'accent_color';

  Box get _box => Hive.box(boxName);

  bool get oledMode => _box.get(kOledMode, defaultValue: false);
  double get glassIntensity => _box.get(kGlassIntensity, defaultValue: 20.0);
  int get minDuration => _box.get(kMinDuration, defaultValue: 30);
  String get artworkQuality =>
      _box.get(kArtworkQuality, defaultValue: 'medium');
  int get accentColor => _box.get(kAccentColor, defaultValue: 0xFF5B13EC);

  Future<void> setOledMode(bool value) => _box.put(kOledMode, value);
  Future<void> setGlassIntensity(double value) =>
      _box.put(kGlassIntensity, value);
  Future<void> setMinDuration(int value) => _box.put(kMinDuration, value);
  Future<void> setArtworkQuality(String value) =>
      _box.put(kArtworkQuality, value);
  Future<void> setAccentColor(int value) => _box.put(kAccentColor, value);
}
