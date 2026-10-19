import 'package:flutter/material.dart';

/// Accent used until a song with artwork is playing
const kDefaultAccent = Color(0xFF7C5CFF);

/// Near-black so OLED pixels stay off
const _background = Color(0xFF0B0B0F);

/// Dark theme whose accent follows the artwork of the current song
ThemeData buildAppTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
    // Stays close to the artwork color instead of drifting to a pastel
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(surface: _background);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: scheme.primary,
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}
