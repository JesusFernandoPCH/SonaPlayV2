import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

Future<void> pickSleepTimer(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const SleepTimerScreen()),
);

const _presets = [15, 30, 45, 60, 90, 120];

/// Countdown ring, quick times, the end of the song or any time up to 23:59
class SleepTimerScreen extends ConsumerStatefulWidget {
  const SleepTimerScreen({super.key});

  @override
  ConsumerState<SleepTimerScreen> createState() => _SleepTimerScreenState();
}

class _SleepTimerScreenState extends ConsumerState<SleepTimerScreen> {
  var _selected = const Duration(minutes: 30);
  var _endOfSong = false;
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Redraws the countdown every second
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  void _choose(Duration duration, {bool endOfSong = false}) => setState(() {
    _selected = duration;
    _endOfSong = endOfSong;
  });

  /// What is left of the song playing now
  Duration? get _songLeft {
    final state = ref.read(playerStateProvider).value;
    if (state == null || state.duration == Duration.zero) return null;
    return state.duration - ref.read(audioHandlerProvider).audioPlayer.position;
  }

  Future<void> _custom() async {
    var picked = _selected;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tiempo personalizado',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            SizedBox(
              height: 216,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(sheet).brightness,
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: _selected,
                  onTimerDurationChanged: (d) => picked = d,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheet, true),
                  child: const Text('Listo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && picked > Duration.zero) _choose(picked);
  }

  void _start() {
    final duration = _endOfSong ? _songLeft : _selected;
    if (duration == null || duration <= Duration.zero) return;
    ref
        .read(sleepTimerProvider.notifier)
        .start(duration, endOfSong: _endOfSong);
  }

  @override
  Widget build(BuildContext context) {
    final ends = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = ends != null;

    final left = running ? ends.difference(DateTime.now()) : _selected;
    final fraction = running
        ? (left.inMilliseconds / max(notifier.total.inMilliseconds, 1))
        // Idle: one turn is an hour
        : min(_selected.inMinutes / 60, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Temporizador'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: SizedBox.square(
              dimension: 260,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.0, 1.0)),
                duration: Motion.slow,
                curve: Motion.enter,
                builder: (_, value, child) => CustomPaint(
                  painter: _Ring(
                    value: value,
                    track: scheme.onSurface.withValues(alpha: 0.08),
                    colors: [scheme.primary, scheme.tertiary],
                    knob: scheme.onSurface,
                  ),
                  child: child,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !running && _endOfSong ? '♪' : _format(left),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        running
                            ? 'PAUSA A LAS ${TimeOfDay.fromDateTime(ends).format(context)}'
                            : _endOfSong
                            ? 'AL TERMINAR LA CANCIÓN'
                            : _selected.inHours > 0
                            ? 'HORAS'
                            : 'MINUTOS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 2,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: running
                ? Row(
                    key: const ValueKey('running'),
                    children: [
                      Expanded(
                        child: _BigButton(
                          icon: AppIcons.stop,
                          label: 'Detener',
                          tonal: true,
                          onPressed: notifier.cancel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigButton(
                          icon: AppIcons.add,
                          label: '10 min',
                          onPressed: () => notifier.start(
                            left + const Duration(minutes: 10),
                          ),
                        ),
                      ),
                    ],
                  )
                : _BigButton(
                    key: const ValueKey('idle'),
                    icon: AppIcons.play,
                    label: 'Iniciar',
                    onPressed: _start,
                  ),
          ),
          const SizedBox(height: 28),
          Text(
            'Pausar en',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                _Choice(
                  label: m < 60
                      ? '$m min'
                      : m % 60 == 0
                      ? '${m ~/ 60} h'
                      : '${m ~/ 60} h ${m % 60}',
                  selected: !_endOfSong && _selected == Duration(minutes: m),
                  onTap: () => _choose(Duration(minutes: m)),
                ),
              _Choice(
                label: 'Fin de la canción',
                icon: AppIcons.music,
                selected: _endOfSong,
                onTap: () => _choose(_selected, endOfSong: true),
              ),
              _Choice(
                label: 'Personalizar',
                icon: AppIcons.edit,
                selected:
                    !_endOfSong &&
                    !_presets.any((m) => _selected == Duration(minutes: m)),
                onTap: _custom,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'El volumen baja poco a poco en los últimos segundos.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  static String _format(Duration d) {
    final s = max(d.inSeconds, 0);
    String two(int n) => n.toString().padLeft(2, '0');
    return s >= 3600
        ? '${s ~/ 3600}:${two(s % 3600 ~/ 60)}:${two(s % 60)}'
        : '${two(s ~/ 60)}:${two(s % 60)}';
  }
}

class _BigButton extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool tonal;

  const _BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
    final iconWidget = AppIcon(icon, size: 20, filled: !tonal);
    return Pressable(
      child: tonal
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              style: style,
              icon: iconWidget,
              label: Text(label),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: iconWidget,
              label: Text(label),
            ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final AppIconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      child: ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : AppIcon(icon!, size: 16),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
    );
  }
}

/// Track, a gradient arc for what's left and a knob at its end
class _Ring extends CustomPainter {
  final double value;
  final Color track;
  final List<Color> colors;
  final Color knob;

  const _Ring({
    required this.value,
    required this.track,
    required this.colors,
    required this.knob,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    final sweep = 2 * pi * value;
    canvas.drawArc(
      rect,
      -pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [colors[0], colors[1], colors[0]],
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
    final angle = -pi / 2 + sweep;
    canvas.drawCircle(
      center + Offset(cos(angle), sin(angle)) * radius,
      stroke * 0.75,
      Paint()..color = knob,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.value != value || old.colors != colors || old.track != track;
}
