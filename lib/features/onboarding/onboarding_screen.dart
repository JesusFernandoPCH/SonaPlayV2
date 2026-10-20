import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/core/appearance/appearance.dart';
import 'package:sonaplay/core/legal/legal.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/settings/presentation/appearance_screen.dart';

/// First launch: welcome, the name to greet you with, the look, and the
/// terms. When
/// only the terms changed, it opens straight on them.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;
  Box get _box => Hive.box('settings_box');

  late final _pages = PageController(
    initialPage: _box.get('onboarded') == true ? _steps - 1 : 0,
  );
  late var _page = _pages.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(duration: Motion.slow, curve: Motion.enter);

  void _saveName(String? name) {
    final clean = name?.trim() ?? '';
    clean.isEmpty ? _box.delete('user_name') : _box.put('user_name', clean);
    FocusScope.of(context).unfocus();
    _next();
  }

  void _accept() {
    _box.put('onboarded', true);
    ref.read(termsAcceptedProvider.notifier).accept();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // Back goes to the previous step, never past the terms
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) {
          _pages.previousPage(duration: Motion.slow, curve: Motion.enter);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < _steps; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i <= _page
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  // Moves only with the buttons, so the terms can't be skipped
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _Welcome(onStart: _next),
                    _Name(
                      initial: _box.get('user_name') as String?,
                      onDone: _saveName,
                    ),
                    _Style(onDone: _next),
                    _Terms(onAccept: _accept),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title, subtitle and content, with the action pinned to the bottom
class _Step extends StatelessWidget {
  final Widget? hero;
  final String title;
  final String subtitle;
  final List<Widget> items;
  final List<Widget> actions;

  const _Step({
    this.hero,
    required this.title,
    required this.subtitle,
    this.items = const [],
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            children: [
              if (hero != null) ...[
                Entrance(child: hero!),
                const SizedBox(height: 28),
              ],
              Entrance(
                delay: staggerDelay(1),
                child: Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Entrance(
                delay: staggerDelay(2),
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (final (i, child) in items.indexed)
                Entrance(delay: staggerDelay(i + 3), child: child),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

ButtonStyle _bigButton(BuildContext context) => FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: Theme.of(context).textTheme.titleMedium
      ?.copyWith(fontWeight: FontWeight.w800),
);

class _Welcome extends StatelessWidget {
  final VoidCallback onStart;
  const _Welcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Step(
      hero: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset('assets/brand/icon.png', width: 112),
          ),
        ),
      ),
      title: 'Bienvenido a SonaPlay',
      subtitle: 'Tu música local, con más vida.',
      items: const [
        _Feature(
          icon: AppIcons.lyrics,
          title: 'Letras sincronizadas',
          text: 'Sigue cada palabra mientras suena.',
        ),
        _Feature(
          icon: AppIcons.sparkles,
          title: 'Una canción para cada día',
          text: 'Redescubre lo que tienes guardado.',
        ),
        _Feature(
          icon: AppIcons.equalizer,
          title: 'A tu manera',
          text: 'Ecualizador, fondos y colores personalizados.',
        ),
      ],
      actions: [
        FilledButton(
          style: _bigButton(context),
          onPressed: onStart,
          child: const Text('Comenzar'),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String text;
  const _Feature({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: AppIcon(icon, size: 24, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Name extends StatefulWidget {
  final String? initial;
  final void Function(String? name) onDone;
  const _Name({required this.initial, required this.onDone});

  @override
  State<_Name> createState() => _NameState();
}

class _NameState extends State<_Name> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _controller.text.trim().isNotEmpty;
    return _Step(
      title: '¿Cómo te llamamos?',
      subtitle:
          'Lo usaremos para saludarte. Se guarda solo en tu teléfono '
          'y puedes cambiarlo en Ajustes.',
      items: [
        TextField(
          controller: _controller,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Tu nombre',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: hasName ? widget.onDone : null,
        ),
      ],
      actions: [
        FilledButton(
          style: _bigButton(context),
          onPressed: hasName ? () => widget.onDone(_controller.text) : null,
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.onDone(null),
          child: const Text('Prefiero no decirlo'),
        ),
      ],
    );
  }
}

/// Background and accent, previewed live (the whole screen changes too)
class _Style extends ConsumerWidget {
  final VoidCallback onDone;
  const _Style({required this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return _Step(
      title: 'Elige tu estilo',
      subtitle:
          'Puedes cambiarlo cuando quieras, o usar una foto tuya, '
          'en Ajustes → Apariencia.',
      items: [
        const AppearancePreview(),
        label('Fondo'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, color) in kBackgroundColors.indexed)
              Swatch(
                label: 'Fondo ${i + 1}',
                selected: a.kind == BackgroundKind.color && a.colorIndex == i,
                decoration: BoxDecoration(color: color),
                onTap: () => notifier.update(
                  (a) => a.copyWith(kind: BackgroundKind.color, colorIndex: i),
                ),
              ),
          ],
        ),
        label('Color de acento'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Swatch(
              label: 'Color de la carátula',
              circle: true,
              selected: a.accentFromArtwork,
              decoration: const BoxDecoration(
                gradient: SweepGradient(
                  colors: [...kAccentColors, Color(0xFF7C5CFF)],
                ),
              ),
              onTap: () =>
                  notifier.update((a) => a.copyWith(accentFromArtwork: true)),
              child: a.accentFromArtwork
                  ? null
                  : const AppIcon(AppIcons.sparkles, color: Colors.white),
            ),
            for (final (i, color) in kAccentColors.indexed)
              Swatch(
                label: 'Acento ${i + 1}',
                circle: true,
                selected: !a.accentFromArtwork && a.accentIndex == i,
                decoration: BoxDecoration(color: color),
                onTap: () => notifier.update(
                  (a) => a.copyWith(accentFromArtwork: false, accentIndex: i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          a.accentFromArtwork
              ? 'El color cambia con la carátula de cada canción.'
              : 'Un color fijo en toda la app.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      actions: [
        FilledButton(
          style: _bigButton(context),
          onPressed: onDone,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _Terms extends StatefulWidget {
  final VoidCallback onAccept;
  const _Terms({required this.onAccept});

  @override
  State<_Terms> createState() => _TermsState();
}

class _TermsState extends State<_Terms> {
  var _checked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );

    return _Step(
      title: 'Antes de empezar',
      subtitle: 'Lo más importante, en corto:',
      items: [
        const _Point(
          icon: AppIcons.music,
          title: 'Tu música es tuya',
          text:
              'SonaPlay solo reproduce archivos que ya están en tu teléfono. '
              'Tú eres responsable de tener derecho a usarlos.',
        ),
        const _Point(
          icon: AppIcons.privacy,
          title: 'Tus datos se quedan aquí',
          text:
              'Tu nombre, listas, favoritas e historial se guardan solo en '
              'este teléfono. No hay cuentas ni publicidad.',
        ),
        const _Point(
          icon: AppIcons.share,
          title: 'Lo poco que se envía',
          text:
              'Reportes de errores y ajustes de la app (Firebase de Google), '
              'y el título y artista al buscar letras (LRCLIB).',
        ),
        const _Point(
          icon: AppIcons.delete,
          title: 'Borrar es definitivo',
          text:
              'Al vaciar "Eliminado recientemente" los archivos se borran '
              'para siempre. Respalda lo importante.',
        ),
        const _Point(
          icon: AppIcons.info,
          title: 'Para mayores de 13 años',
          text: 'Si eres menor de 18, úsala con permiso de tu madre, padre o tutor.',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => openLegal(context, privacy: false),
                child: const Text('Términos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => openLegal(context, privacy: true),
                child: const Text('Privacidad'),
              ),
            ),
          ],
        ),
      ],
      actions: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _checked = !_checked),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _checked,
                onChanged: (v) => setState(() => _checked = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 8),
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Leí y acepto los '),
                        TextSpan(text: 'Términos y Condiciones', style: link),
                        const TextSpan(text: ' y el '),
                        TextSpan(text: 'Aviso de Privacidad', style: link),
                        const TextSpan(text: ', y tengo al menos 13 años.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: _bigButton(context),
          onPressed: _checked ? widget.onAccept : null,
          child: const Text('Aceptar y continuar'),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  final AppIconData icon;
  final String title;
  final String text;
  const _Point({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
