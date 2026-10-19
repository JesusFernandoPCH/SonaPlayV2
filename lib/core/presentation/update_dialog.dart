import 'package:flutter/material.dart';
import 'package:sonaplay/core/services/update_service.dart';

/// Fetches Remote Config and, when this version is below min_version_required,
/// blocks the app with a dialog that sends the user to the store
Future<void> checkForRequiredUpdate(GlobalKey<NavigatorState> navigator) async {
  final service = UpdateService();
  await service.initialize();
  if (!await service.isUpdateRequired()) return;
  final context = navigator.currentContext;
  if (context == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_rounded),
        title: const Text('Actualización necesaria'),
        content: const Text(
          'Esta versión de SonaPlay ya no es compatible. '
          'Actualiza la app para seguir usándola.',
        ),
        actions: [
          FilledButton(
            onPressed: service.openUpdateUrl,
            child: const Text('Actualizar'),
          ),
        ],
      ),
    ),
  );
}
