import 'package:audio_waveforms/audio_waveforms.dart' show PlayerController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/services/ringtone_service.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

const _bars = 90;
const _defaultLength = Duration(seconds: 30);

/// Pick a range of a song, preview it and save it as the phone's ringtone
class RingtoneTrimmerScreen extends ConsumerStatefulWidget {
  final Song song;
  const RingtoneTrimmerScreen({super.key, required this.song});

  @override
  ConsumerState<RingtoneTrimmerScreen> createState() =>
      _RingtoneTrimmerScreenState();
}

class _RingtoneTrimmerScreenState extends ConsumerState<RingtoneTrimmerScreen> {
  // Only used to read the waveform; playback goes through just_audio
  final _waveformReader = PlayerController();
  final _preview = AudioPlayer();
  List<double>? _waveform;
  late Duration _total;
  late RangeValues _range;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _total = Duration(milliseconds: widget.song.duration ?? 0);
    final end = _total < _defaultLength ? _total : _defaultLength;
    _range = RangeValues(0, end.inMilliseconds.toDouble());
    _waveformReader.waveformExtraction
        .extractWaveformData(path: widget.song.filePath, noOfSamples: _bars)
        .then((data) => mounted ? setState(() => _waveform = data) : null)
        // Unsupported formats still get a flat waveform and can be trimmed
        .catchError((_) {
          if (mounted) setState(() => _waveform = const []);
        });
  }

  @override
  void dispose() {
    _waveformReader.dispose();
    _preview.dispose();
    super.dispose();
  }

  Duration get _start => Duration(milliseconds: _range.start.round());
  Duration get _end => Duration(milliseconds: _range.end.round());

  Future<void> _togglePreview() async {
    if (_preview.playing) return _preview.stop();
    await ref.read(audioHandlerProvider).pause();
    await _preview.setAudioSource(
      ClippingAudioSource(
        child: AudioSource.file(widget.song.filePath),
        start: _start,
        end: _end,
      ),
    );
    await _preview.play();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    await _preview.stop();
    String message;
    var done = false;
    try {
      done = await RingtoneService.setAsRingtone(
        filePath: widget.song.filePath,
        title: widget.song.title,
        startSeconds: _start.inMilliseconds / 1000,
        endSeconds: _end.inMilliseconds / 1000,
      );
      message = done ? 'Tono de llamada establecido' : 'No se pudo guardar';
    } on RingtonePermissionException {
      message = 'Activa el permiso y vuelve a tocar Guardar';
    } catch (_) {
      message = 'Este formato no se puede recortar';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    if (done) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = _total.inMilliseconds.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Tono de llamada')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Artwork(songId: song.id),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 120,
                child: _waveform == null
                    ? const Center(child: CircularProgressIndicator())
                    // Inset like the slider track, which stops at the thumb's center
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _WaveformPainter(
                            samples: _waveform!,
                            from: max == 0 ? 0 : _range.start / max,
                            to: max == 0 ? 1 : _range.end / max,
                            active: scheme.primary,
                            inactive: scheme.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
              ),
              // No inner padding, so the track lines up with the waveform bars
              SliderTheme(
                data: SliderTheme.of(
                  context,
                ).copyWith(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: RangeSlider(
                  values: _range,
                  max: max == 0 ? 1 : max,
                  // Never shorter than one second
                  onChanged: max == 0
                      ? null
                      : (r) {
                          if (r.end - r.start >= 1000) {
                            setState(() => _range = r);
                          }
                        },
                  onChangeEnd: (_) => _preview.stop(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(_start)),
                  Text(
                    'Duración ${_format(_end - _start)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(_format(_end)),
                ],
              ),
              const Spacer(),
              StreamBuilder<bool>(
                stream: _preview.playingStream,
                builder: (context, snap) {
                  final playing = snap.data ?? false;
                  return OutlinedButton.icon(
                    onPressed: _togglePreview,
                    icon: AppIcon(playing ? AppIcons.stop : AppIcons.play),
                    label: Text(playing ? 'Detener' : 'Escuchar fragmento'),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || max == 0 ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppIcon(AppIcons.ringtone),
                  label: const Text('Guardar como tono de llamada'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _format(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Bars for the song's loudness, highlighted inside the chosen range
class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double from;
  final double to;
  final Color active;
  final Color inactive;

  _WaveformPainter({
    required this.samples,
    required this.from,
    required this.to,
    required this.active,
    required this.inactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = samples.isEmpty ? _bars : samples.length;
    final peak = samples.fold<double>(0, (m, s) => s.abs() > m ? s.abs() : m);
    final slot = size.width / count;
    final paint = Paint()
      ..strokeWidth = slot * 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final level = samples.isEmpty || peak == 0
          ? 0.1
          : (samples[i].abs() / peak).clamp(0.05, 1.0);
      final x = slot * (i + 0.5);
      final half = size.height * level / 2;
      paint.color = x / size.width >= from && x / size.width <= to
          ? active
          : inactive;
      canvas.drawLine(
        Offset(x, size.height / 2 - half),
        Offset(x, size.height / 2 + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.samples != samples || old.from != from || old.to != to;
}
