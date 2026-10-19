import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/services/permission_service.dart';
import 'package:sonaplay/features/library/presentation/screens/library_screen.dart';

final _permissionService = PermissionService();

final audioPermissionProvider = FutureProvider<bool>(
  (ref) => _permissionService.hasAudioPermission(),
);

/// Shows the library once audio access is granted, the permission screen before
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(audioPermissionProvider)) {
      AsyncData(value: true) => const LibraryScreen(),
      AsyncData() => const _PermissionScreen(),
      _ => const Scaffold(),
    };
  }
}

class _PermissionScreen extends ConsumerStatefulWidget {
  const _PermissionScreen();

  @override
  ConsumerState<_PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<_PermissionScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    // Coming back from system settings: check again
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(audioPermissionProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_permanentlyDenied) return _permissionService.openSettings();
    await _permissionService.requestAudioPermission();
    final denied = await _permissionService
        .isAudioPermissionPermanentlyDenied();
    if (mounted) setState(() => _permanentlyDenied = denied);
    ref.invalidate(audioPermissionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.library_music_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Tu música, en SonaPlay',
                textAlign: TextAlign.center,
                style: text.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _permanentlyDenied
                    ? 'El permiso está bloqueado. Actívalo en Ajustes > Permisos > Música y audio.'
                    : 'Necesitamos acceso a los archivos de audio del teléfono para mostrar tu biblioteca.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _request,
                child: Text(
                  _permanentlyDenied
                      ? 'Abrir configuración'
                      : 'Permitir acceso',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
