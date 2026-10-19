import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/settings/data/datasources/settings_local_datasource.dart';

typedef _Preset = ({
  String name,
  AppIconData icon,
  // Gain as a fraction of the max boost, by band center frequency in Hz
  double Function(double hz) gain,
});

final List<_Preset> _presets = [
  (name: 'Plano', icon: HugeIcons.strokeRoundedAudioWaveform, gain: (hz) => 0),
  (
    name: 'Graves',
    icon: HugeIcons.strokeRoundedSpeaker01,
    gain: (hz) => hz <= 250 ? 0.6 : (hz <= 600 ? 0.2 : 0),
  ),
  (
    name: 'Voces',
    icon: HugeIcons.strokeRoundedMic01,
    gain: (hz) => hz < 300 ? -0.2 : (hz <= 4000 ? 0.4 : 0.1),
  ),
  (
    name: 'Agudos',
    icon: HugeIcons.strokeRoundedSparkles,
    gain: (hz) => hz >= 4000 ? 0.5 : (hz >= 1500 ? 0.2 : 0),
  ),
  (
    name: 'Pop',
    icon: HugeIcons.strokeRoundedStar,
    gain: (hz) => hz < 250 ? 0.1 : (hz <= 4000 ? 0.3 : 0.2),
  ),
  (
    name: 'Rock',
    icon: HugeIcons.strokeRoundedGuitar,
    gain: (hz) => hz < 300 ? 0.4 : (hz <= 2000 ? -0.1 : 0.4),
  ),
  (
    name: 'Electrónica',
    icon: HugeIcons.strokeRoundedFlash,
    gain: (hz) => hz < 250 ? 0.5 : (hz <= 2000 ? 0 : 0.3),
  ),
  (
    name: 'Hip-hop',
    icon: HugeIcons.strokeRoundedHeadphones,
    gain: (hz) => hz < 250 ? 0.6 : (hz <= 1000 ? 0.2 : 0.1),
  ),
];

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equalizer = ref.watch(audioHandlerProvider).audioPlayer.equalizer;
    final hasSong = ref.watch(currentSongProvider).value != null;
    final settings = SettingsLocalDataSource();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          'Ecualizador',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          StreamBuilder<bool>(
            stream: equalizer.enabledStream,
            builder: (context, snap) => Switch(
              value: snap.data ?? false,
              onChanged: (on) {
                equalizer.setEnabled(on);
                settings.setEqualizerEnabled(on);
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: !hasSong
          // The native equalizer only exists once audio has been loaded
          ? const Center(child: Text('Reproduce una canción para ajustarlo'))
          : FutureBuilder<AndroidEqualizerParameters>(
              future: equalizer.parameters,
              builder: (context, snap) {
                final params = snap.data;
                if (params == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<bool>(
                  stream: equalizer.enabledStream,
                  builder: (context, enabled) => _Bands(
                    params: params,
                    enabled: enabled.data ?? false,
                    enable: () {
                      equalizer.setEnabled(true);
                      settings.setEqualizerEnabled(true);
                    },
                    settings: settings,
                  ),
                );
              },
            ),
    );
  }
}

class _Bands extends StatefulWidget {
  final AndroidEqualizerParameters params;
  final bool enabled;
  final VoidCallback enable;
  final SettingsLocalDataSource settings;

  const _Bands({
    required this.params,
    required this.enabled,
    required this.enable,
    required this.settings,
  });

  @override
  State<_Bands> createState() => _BandsState();
}

const _labelHeight = 20.0;
const _gap = 14.0;

class _BandsState extends State<_Bands> {
  late final List<double> _gains = [
    for (final b in widget.params.bands) b.gain,
  ];

  AndroidEqualizerParameters get _params => widget.params;

  void _setGain(int i, double gain) {
    // Touching a band means the user wants to hear it
    if (!widget.enabled) widget.enable();
    setState(() => _gains[i] = gain);
    _params.bands[i].setGain(gain);
  }

  void _save() => widget.settings.setEqualizerGains(_gains);

  void _applyPreset(_Preset preset) {
    for (final (i, band) in _params.bands.indexed) {
      _setGain(i, preset.gain(band.centerFrequency) * _params.maxDecibels);
    }
    _save();
  }

  bool _matches(_Preset preset) => _params.bands.indexed.every(
    (e) =>
        (preset.gain(e.$2.centerFrequency) * _params.maxDecibels - _gains[e.$1])
            .abs() <
        0.3,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final min = _params.minDecibels;
    final max = _params.maxDecibels;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AnimatedOpacity(
          duration: Motion.medium,
          // Dimmed while off, still adjustable (which turns it on)
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
            ),
            child: SizedBox(
              height: 300,
              child: Stack(
                children: [
                  // The response curve through every band, behind the sliders
                  Positioned.fill(
                    top: _labelHeight + _gap,
                    bottom: _labelHeight + _gap,
                    child: CustomPaint(
                      painter: _CurvePainter(
                        values: [
                          for (final g in _gains) (g - min) / (max - min),
                        ],
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, band) in _params.bands.indexed)
                        Expanded(
                          child: Column(
                            children: [
                              SizedBox(
                                height: _labelHeight,
                                child: Text(
                                  '${_gains[i] >= 0 ? '+' : ''}${_gains[i].toStringAsFixed(0)}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: _gap),
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      // No inner padding: the track spans
                                      // exactly the area the curve is drawn in
                                      padding: EdgeInsets.zero,
                                      trackHeight: 4,
                                      activeTrackColor: Colors.transparent,
                                      inactiveTrackColor: scheme.onSurface
                                          .withValues(alpha: 0.12),
                                      thumbColor: scheme.primary,
                                      overlayColor: scheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _gains[i].clamp(min, max),
                                      min: min,
                                      max: max,
                                      onChanged: (v) => _setGain(i, v),
                                      onChangeEnd: (_) => _save(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: _gap),
                              SizedBox(
                                height: _labelHeight,
                                child: Text(
                                  _frequency(band.centerFrequency),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Preajustes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            for (final preset in _presets)
              _PresetCard(
                preset: preset,
                selected: widget.enabled && _matches(preset),
                onTap: () => _applyPreset(preset),
              ),
          ],
        ),
      ],
    );
  }

  static String _frequency(double hz) => hz < 1000
      ? '${hz.round()}'
      : '${(hz / 1000).toStringAsFixed(hz < 10000 ? 1 : 0)}K';
}

class _PresetCard extends StatelessWidget {
  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.enter,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.22)
              : scheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppIcon(preset.icon, color: selected ? scheme.primary : null),
                  Text(
                    preset.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Smooth line through the band levels (0 bottom to 1 top), with a soft fill
class _CurvePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _CurvePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final step = size.width / values.length;
    final points = [
      for (final (i, v) in values.indexed)
        Offset(step * (i + 0.5), size.height * (1 - v.clamp(0, 1))),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      // Horizontal tangents make a gentle S between neighbours
      final a = points[i - 1];
      final b = points[i];
      final midX = (a.dx + b.dx) / 2;
      line.cubicTo(midX, a.dy, midX, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.color != color || !_sameValues(old.values);

  bool _sameValues(List<double> other) {
    if (other.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (other[i] != values[i]) return false;
    }
    return true;
  }
}
