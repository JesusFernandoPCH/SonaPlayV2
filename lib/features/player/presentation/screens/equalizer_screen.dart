import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/settings/data/datasources/settings_local_datasource.dart';

/// Presets as a gain (fraction of the max boost) by band center frequency in Hz
final Map<String, double Function(double hz)> _presets = {
  'Plano': (hz) => 0,
  'Graves': (hz) => hz <= 250 ? 0.6 : 0,
  'Voces': (hz) => hz >= 500 && hz <= 4000 ? 0.4 : 0,
  'Agudos': (hz) => hz >= 4000 ? 0.5 : 0,
};

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equalizer = ref.watch(audioHandlerProvider).audioPlayer.equalizer;
    final hasSong = ref.watch(currentSongProvider).value != null;
    final settings = SettingsLocalDataSource();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ecualizador'),
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
          const SizedBox(width: 8),
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
                return _Bands(params: params, settings: settings);
              },
            ),
    );
  }
}

class _Bands extends StatelessWidget {
  final AndroidEqualizerParameters params;
  final SettingsLocalDataSource settings;

  const _Bands({required this.params, required this.settings});

  void _save() =>
      settings.setEqualizerGains([for (final b in params.bands) b.gain]);

  Future<void> _applyPreset(double Function(double hz) gainFor) async {
    for (final band in params.bands) {
      await band.setGain(gainFor(band.centerFrequency) * params.maxDecibels);
    }
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final preset in _presets.entries)
              ActionChip(
                label: Text(preset.key),
                onPressed: () => _applyPreset(preset.value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final band in params.bands)
          StreamBuilder<double>(
            stream: band.gainStream,
            builder: (context, snap) {
              final gain = snap.data ?? band.gain;
              return Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(_frequency(band.centerFrequency)),
                  ),
                  Expanded(
                    child: Slider(
                      value: gain.clamp(params.minDecibels, params.maxDecibels),
                      min: params.minDecibels,
                      max: params.maxDecibels,
                      label: '${gain.toStringAsFixed(1)} dB',
                      onChanged: band.setGain,
                      onChangeEnd: (_) => _save(),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  static String _frequency(double hz) => hz < 1000
      ? '${hz.round()} Hz'
      : '${(hz / 1000).toStringAsFixed(hz < 10000 ? 1 : 0)} kHz';
}
