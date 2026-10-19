import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  final _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setDefaults({
        "min_version_required":
            "1.0.0", //no olvidar cambiar pubspec.yaml linea 19
        "update_url":
            "https://play.google.com/store/apps/details?id=com.example.sonaplay",
      });

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 12),
        ),
      );

      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Error initializing Remote Config: $e');
    }
  }

  Future<bool> isUpdateRequired() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final minVersion = _remoteConfig.getString("min_version_required");

      return _isVersionLower(currentVersion, minVersion);
    } catch (e) {
      debugPrint('Error checking update requirements: $e');
      return false;
    }
  }

  String get updateUrl => _remoteConfig.getString("update_url");

  bool _isVersionLower(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length && i < minParts.length; i++) {
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }

    return currentParts.length < minParts.length;
  }
}
