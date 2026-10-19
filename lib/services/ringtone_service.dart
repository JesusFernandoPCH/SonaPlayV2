import 'dart:io';

import 'package:flutter/services.dart';

class RingtonePermissionException implements Exception {}

class RingtoneService {
  static const MethodChannel _channel = MethodChannel('sonaplay/ringtone');

  /// Delega el recorte y el establecimiento del Tono de Llamada a la capa Nativa Android
  static Future<bool> setAsRingtone({
    required String filePath,
    required String title,
    required double startSeconds,
    required double endSeconds,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Función exclusiva de Android');
    }
    if (!File(filePath).existsSync()) {
      throw const FileSystemException('Archivo de origen nulo o no encontrado');
    }

    try {
      final bool result = await _channel.invokeMethod('setAndroidRingtone', {
        'path': filePath,
        'title': title,
        // Convertimos a milisegundos para el extractor nativo de Android
        'startTimeMs': (startSeconds * 1000).toInt(),
        'endTimeMs': (endSeconds * 1000).toInt(),
      });
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSIONS_REQUIRED' || e.code == 'REQUIRES_PERMISSION') {
        throw RingtonePermissionException();
      }
      throw Exception(
        e.message ??
            'Fallo desconocido en la capa nativa al recortar el audio.',
      );
    }
  }
}
