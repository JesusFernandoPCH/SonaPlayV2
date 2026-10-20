import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/legal/legal.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/permission_gate.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/onboarding/onboarding_screen.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Lets code outside the widget tree (the update check) show dialogs
final appNavigatorKey = GlobalKey<NavigatorState>();

class SonaPlayApp extends ConsumerWidget {
  const SonaPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider).value ?? kDefaultAccent;
    return MaterialApp(
      title: 'SonaPlay',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(accent),
      // System texts (pickers, tooltips) in Spanish
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Welcome and terms first; the library once they're accepted
      home: AnimatedSwitcher(
        duration: Motion.slow,
        child: ref.watch(termsAcceptedProvider)
            ? const PermissionGate()
            : const OnboardingScreen(),
      ),
    );
  }
}
