import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sonaplay/core/appearance/appearance.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final theme = Theme.of(context);

    Future<void> pickFromGallery() async {
      // No resize options: they would turn a GIF into a still JPEG
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file != null) await notifier.useImageFile(file.path);
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );

    final customImage =
        a.kind == BackgroundKind.image &&
        a.imagePath != null &&
        !a.imagePath!.startsWith('asset:');

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Preview(),
          header('Fondo'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, color) in kBackgroundColors.indexed)
                  _Swatch(
                    label: 'Color ${i + 1}',
                    selected:
                        a.kind == BackgroundKind.color && a.colorIndex == i,
                    decoration: BoxDecoration(color: color),
                    onTap: () => notifier.update(
                      (a) =>
                          a.copyWith(kind: BackgroundKind.color, colorIndex: i),
                    ),
                  ),
                for (final (i, colors) in kBackgroundGradients.indexed)
                  _Swatch(
                    label: 'Degradado ${i + 1}',
                    selected:
                        a.kind == BackgroundKind.gradient &&
                        a.gradientIndex == i,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                    ),
                    onTap: () => notifier.update(
                      (a) => a.copyWith(
                        kind: BackgroundKind.gradient,
                        gradientIndex: i,
                      ),
                    ),
                  ),
                for (final asset in kBackgroundAssets)
                  _Swatch(
                    label: 'Ondas',
                    selected:
                        a.kind == BackgroundKind.image && a.imagePath == asset,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(asset.substring(6)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    onTap: () => notifier.update(
                      (a) => a.copyWith(
                        kind: BackgroundKind.image,
                        imagePath: asset,
                      ),
                    ),
                  ),
                _Swatch(
                  label: 'Elegir de la galería',
                  selected: customImage,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  onTap: pickFromGallery,
                  child: AppIcon(
                    AppIcons.imageAdd,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (a.kind == BackgroundKind.image) ...[
            _SliderTile(
              icon: AppIcons.blur,
              label: 'Difuminado',
              value: a.blur,
              max: 30,
              display: a.blur == 0 ? 'Nada' : a.blur.round().toString(),
              onChanged: (v) => notifier.update((a) => a.copyWith(blur: v)),
            ),
            _SliderTile(
              icon: AppIcons.dim,
              label: 'Oscurecer',
              value: a.dim,
              max: 0.8,
              display: '${(a.dim * 100).round()}%',
              onChanged: (v) => notifier.update((a) => a.copyWith(dim: v)),
            ),
            if (a.isGif)
              const ListTile(
                leading: AppIcon(AppIcons.battery),
                subtitle: Text(
                  'Los GIF animados gastan un poco más de batería. '
                  'Se pausan cuando la app no está en pantalla.',
                ),
              ),
          ],
          header('Color de acento'),
          SwitchListTile(
            title: const Text('Usar el color de la carátula'),
            subtitle: const Text('Cambia con cada canción'),
            value: a.accentFromArtwork,
            onChanged: (v) =>
                notifier.update((a) => a.copyWith(accentFromArtwork: v)),
          ),
          if (!a.accentFromArtwork)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, color) in kAccentColors.indexed)
                    _Swatch(
                      label: 'Acento ${i + 1}',
                      circle: true,
                      selected: a.accentIndex == i,
                      decoration: BoxDecoration(color: color),
                      onTap: () =>
                          notifier.update((a) => a.copyWith(accentIndex: i)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A phone-shaped sample of the current background, accent and text
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget line(double width, double alpha) => Container(
      height: 10,
      width: width,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(5),
      ),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 180,
            height: 320,
            child: AppBackground(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canciones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: i == 1
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                line(90.0 - i * 8, 0.85),
                                const SizedBox(height: 4),
                                line(60, 0.45),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 6),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: AppIcon(
                          AppIcons.pause,
                          size: 16,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final bool selected;
  final BoxDecoration decoration;
  final VoidCallback onTap;
  final Widget? child;
  final bool circle;

  const _Swatch({
    required this.label,
    required this.selected,
    required this.decoration,
    required this.onTap,
    this.child,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(circle ? 28 : 14);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(circle ? 25 : 11),
            child: DecoratedBox(
              decoration: decoration,
              child: Center(
                child:
                    child ??
                    (selected
                        ? const AppIcon(AppIcons.check, color: Colors.white)
                        : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final double value;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(
      children: [
        AppIcon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    ),
  );
}
