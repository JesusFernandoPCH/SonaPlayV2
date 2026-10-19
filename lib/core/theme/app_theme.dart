import 'package:flutter/material.dart';
import 'package:sonaplay/core/appearance/appearance.dart';

/// Accent used until a song with artwork is playing
const kDefaultAccent = Color(0xFF7C5CFF);

/// Dark theme whose accent follows the artwork of the current song (or the
/// fixed accent). Screens are transparent: the background is drawn per page by
/// [BackdropPageTransitionsBuilder].
ThemeData buildAppTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    // Stays close to the artwork color instead of drifting to a pastel
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(surface: kBackgroundColors.first);

  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Satoshi',
    scaffoldBackgroundColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: BackdropPageTransitionsBuilder()},
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: barColor(scheme),
      indicatorColor: scheme.primary.withValues(alpha: 0.24),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Satoshi',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: const TextStyle(
        fontFamily: 'Satoshi',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: scheme.primary,
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}

/// Bars float over the background: tinted and slightly see-through
Color barColor(ColorScheme scheme) => Color.alphaBlend(
  scheme.primary.withValues(alpha: 0.10),
  scheme.surfaceContainer,
).withValues(alpha: 0.92);
