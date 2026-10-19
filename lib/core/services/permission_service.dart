import 'package:permission_handler/permission_handler.dart';

/// Service to handle runtime permissions
class PermissionService {
  /// Request audio file access permission
  /// Returns true if granted, false otherwise
  Future<bool> requestAudioPermission() async {
    // Android 13+ uses READ_MEDIA_AUDIO
    // Android 6-12 uses READ_EXTERNAL_STORAGE
    final status = await Permission.audio.request();

    return status.isGranted;
  }

  /// Check if audio permission is granted
  Future<bool> hasAudioPermission() async {
    final status = await Permission.audio.status;
    return status.isGranted;
  }

  /// Check if permission is permanently denied
  Future<bool> isAudioPermissionPermanentlyDenied() async {
    final status = await Permission.audio.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings (when permission is permanently denied)
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
