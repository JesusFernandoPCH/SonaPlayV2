import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonaplay/core/motion/motion.dart';

/// What sits behind every screen
enum BackgroundKind { color, gradient, image }

/// Solid backgrounds, darkest first (the first is the default)
const kBackgroundColors = [
  Color(0xFF0B0B0F), // Negro
  Color(0xFF0E1630), // Medianoche
  Color(0xFF1A1033), // Violeta
  Color(0xFF0E1F1A), // Bosque
  Color(0xFF2A0E17), // Vino
  Color(0xFF1C1C22), // Carbón
];

const kBackgroundGradients = [
  [Color(0xFF2A1D63), Color(0xFF0B0B0F), Color(0xFF0B3A4A)], // Aurora
  [Color(0xFF3A0CA3), Color(0xFF14061F), Color(0xFF7A1450)], // Atardecer
  [Color(0xFF023E8A), Color(0xFF03045E), Color(0xFF050814)], // Océano
];

/// Images shipped with the app, referenced as `asset:<path>`
const kBackgroundAssets = ['asset:assets/backgrounds/waves.jpg'];

/// Fixed accents for when the artwork color is turned off
const kAccentColors = [
  Color(0xFF7C5CFF),
  Color(0xFF22D3EE),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFF87171),
  Color(0xFFF472B6),
];

@immutable
class Appearance {
  final BackgroundKind kind;
  final int colorIndex;
  final int gradientIndex;

  /// File path, or `asset:<path>` for a bundled image
  final String? imagePath;

  /// Blur sigma for images, 0 to 30
  final double blur;

  /// Black overlay opacity so text stays readable, 0 to 0.8
  final double dim;

  final bool accentFromArtwork;
  final int accentIndex;

  const Appearance({
    this.kind = BackgroundKind.color,
    this.colorIndex = 0,
    this.gradientIndex = 0,
    this.imagePath,
    this.blur = 12,
    this.dim = 0.45,
    this.accentFromArtwork = true,
    this.accentIndex = 0,
  });

  Color get fixedAccent => kAccentColors[accentIndex];

  bool get isGif => imagePath?.toLowerCase().endsWith('.gif') ?? false;

  Appearance copyWith({
    BackgroundKind? kind,
    int? colorIndex,
    int? gradientIndex,
    String? imagePath,
    double? blur,
    double? dim,
    bool? accentFromArtwork,
    int? accentIndex,
  }) => Appearance(
    kind: kind ?? this.kind,
    colorIndex: colorIndex ?? this.colorIndex,
    gradientIndex: gradientIndex ?? this.gradientIndex,
    imagePath: imagePath ?? this.imagePath,
    blur: blur ?? this.blur,
    dim: dim ?? this.dim,
    accentFromArtwork: accentFromArtwork ?? this.accentFromArtwork,
    accentIndex: accentIndex ?? this.accentIndex,
  );

  Map<String, Object?> toMap() => {
    'kind': kind.index,
    'color': colorIndex,
    'gradient': gradientIndex,
    'image': imagePath,
    'blur': blur,
    'dim': dim,
    'accentFromArtwork': accentFromArtwork,
    'accent': accentIndex,
  };

  factory Appearance.fromMap(Map map) {
    int index(Object? v, int length) =>
        v is int && v >= 0 && v < length ? v : 0;
    final image = map['image'] as String?;
    final kind =
        BackgroundKind.values[index(map['kind'], BackgroundKind.values.length)];
    // A picked file can be gone (app data cleared): fall back to the default
    final imageMissing =
        image == null ||
        (!image.startsWith('asset:') && !File(image).existsSync());
    return Appearance(
      kind: kind == BackgroundKind.image && imageMissing
          ? BackgroundKind.color
          : kind,
      colorIndex: index(map['color'], kBackgroundColors.length),
      gradientIndex: index(map['gradient'], kBackgroundGradients.length),
      imagePath: imageMissing ? null : image,
      blur: (map['blur'] as num?)?.toDouble() ?? 12,
      dim: (map['dim'] as num?)?.toDouble() ?? 0.45,
      accentFromArtwork: map['accentFromArtwork'] as bool? ?? true,
      accentIndex: index(map['accent'], kAccentColors.length),
    );
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  static const _key = 'appearance';
  Box get _box => Hive.box('settings_box');

  @override
  Appearance build() =>
      Appearance.fromMap(_box.get(_key, defaultValue: const {}) as Map);

  void update(Appearance Function(Appearance) change) {
    state = change(state);
    _box.put(_key, state.toMap());
  }

  /// Copies a picked image or GIF into app storage (the original may be
  /// moved or deleted later) and uses it as the background
  Future<void> useImageFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = sourcePath.split('.').last.toLowerCase();
    // New name each time, so the image cache never serves the previous one
    final target = File(
      '${dir.path}/background_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await File(sourcePath).copy(target.path);
    final previous = state.imagePath;
    update(
      (a) => a.copyWith(kind: BackgroundKind.image, imagePath: target.path),
    );
    if (previous != null && !previous.startsWith('asset:')) {
      final old = File(previous);
      if (old.existsSync()) await old.delete();
    }
  }
}

/// The chosen background, with [child] on top
class AppBackground extends ConsumerWidget {
  final Widget child;
  final Appearance? preview;
  const AppBackground({super.key, required this.child, this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Appearance a = preview ?? ref.watch(appearanceProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: _Layer(appearance: a)),
        child,
      ],
    );
  }
}

class _Layer extends StatelessWidget {
  final Appearance appearance;
  const _Layer({required this.appearance});

  @override
  Widget build(BuildContext context) {
    final a = appearance;
    switch (a.kind) {
      case BackgroundKind.color:
        return ColoredBox(color: kBackgroundColors[a.colorIndex]);
      case BackgroundKind.gradient:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: kBackgroundGradients[a.gradientIndex],
            ),
          ),
        );
      case BackgroundKind.image:
        final path = a.imagePath!;
        // Decoded at screen size: a 4000px photo would waste memory
        final width =
            (MediaQuery.sizeOf(context).width *
                    MediaQuery.devicePixelRatioOf(context))
                .round();
        final image = path.startsWith('asset:')
            ? Image.asset(
                path.substring(6),
                fit: BoxFit.cover,
                cacheWidth: width,
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: width,
                gaplessPlayback: true,
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (a.blur > 0)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: a.blur,
                  sigmaY: a.blur,
                  tileMode: TileMode.clamp,
                ),
                child: image,
              )
            else
              image,
            ColoredBox(color: Colors.black.withValues(alpha: a.dim)),
          ],
        );
    }
  }
}

/// Wraps every page in the background, so pages stay opaque during
/// transitions (no ghosting) while scaffolds themselves are transparent,
/// and moves them with the app's own shared-axis transition
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackdropPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SharedAxisTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    child: AppBackground(child: child),
  );
}
