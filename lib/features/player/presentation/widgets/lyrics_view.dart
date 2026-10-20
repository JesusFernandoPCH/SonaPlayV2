import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/data/lyrics_source.dart';
import 'package:sonaplay/features/player/domain/lyrics.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

final lyricsSourceProvider = Provider((ref) => LyricsSource());

/// Lyrics of the song playing now; null when none were found
final lyricsProvider = FutureProvider.autoDispose<List<LyricLine>?>((
  ref,
) async {
  final song = ref.watch(currentSongProvider).value;
  if (song == null) return null;
  final raw = await ref.watch(lyricsSourceProvider).load(song);
  if (raw == null) return null;
  final lines = parseLyrics(raw);
  return lines.isEmpty ? null : lines;
});

/// Lyrics of the current song; synced ones follow the music word by word
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentSongProvider).value?.id;
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: switch (ref.watch(lyricsProvider)) {
        AsyncData(:final value?) when value.first.time != null => _Synced(
          key: ValueKey(id),
          lines: value,
        ),
        AsyncData(:final value?) => _Plain(key: ValueKey(id), lines: value),
        AsyncData() || AsyncError() => _NoLyrics(key: ValueKey(id)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Synced extends ConsumerStatefulWidget {
  final List<LyricLine> lines;
  const _Synced({super.key, required this.lines});

  @override
  ConsumerState<_Synced> createState() => _SyncedState();
}

class _SyncedState extends ConsumerState<_Synced>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _scroll = ScrollController();
  late final _keys = [for (final _ in widget.lines) GlobalKey()];
  var _line = -1;
  var _lit = 0;

  /// The user scrolled to read ahead; follow the song again after this
  DateTime _manualUntil = DateTime(0);

  @override
  void initState() {
    super.initState();
    // Reads the live position every frame, so words light up on time; only
    // rebuilds when the line or the lit word changes
    _ticker = createTicker((_) {
      final position = ref.read(audioHandlerProvider).audioPlayer.position;
      final line = lineAt(widget.lines, position);
      final lit = line < 0
          ? 0
          : litWords(
              widget.lines[line].text,
              lineProgress(widget.lines, line, position),
            ).lit;
      if (line == _line && lit == _lit) return;
      final moved = line != _line;
      setState(() {
        _line = line;
        _lit = lit;
      });
      if (moved) _follow();
    })..start();
  }

  void _follow({bool jump = false}) {
    if (DateTime.now().isBefore(_manualUntil) || _line < 0) return;
    final target = _keys[_line].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.35,
      duration: jump ? Duration.zero : Motion.slow,
      curve: Motion.enter,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.3,
    );

    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _manualUntil = DateTime.now().add(const Duration(seconds: 3));
        return false;
      },
      child: ShaderMask(
        // Lines fade out at the top and bottom edges
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.08, 0.85, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in widget.lines.indexed)
                GestureDetector(
                  key: _keys[i],
                  behavior: HitTestBehavior.opaque,
                  // Tap a line to jump there
                  onTap: () {
                    _manualUntil = DateTime(0);
                    ref.read(audioHandlerProvider).audioPlayer.seek(line.time!);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedScale(
                      scale: i == _line ? 1 : 0.94,
                      alignment: Alignment.centerLeft,
                      duration: Motion.medium,
                      curve: Motion.enter,
                      child: i == _line
                          ? _CurrentLine(
                              text: line.text,
                              lit: _lit,
                              style: style,
                              scheme: scheme,
                            )
                          : AnimatedOpacity(
                              opacity: i < _line ? 0.45 : 0.3,
                              duration: Motion.medium,
                              child: Text(
                                line.text.isEmpty ? '♪' : line.text,
                                style: style.copyWith(color: scheme.onSurface),
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The line being sung: words already sung in full color, the one being
/// sung in the accent color, the rest dimmed
class _CurrentLine extends StatelessWidget {
  final String text;
  final int lit;
  final TextStyle style;
  final ColorScheme scheme;

  const _CurrentLine({
    required this.text,
    required this.lit,
    required this.style,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Text('♪', style: style.copyWith(color: scheme.primary));
    }
    final words = text.split(' ');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, word) in words.indexed)
            TextSpan(
              text: i == words.length - 1 ? word : '$word ',
              style: TextStyle(
                color: i == lit - 1
                    ? scheme.primary
                    : i < lit
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  final List<LyricLine> lines;
  const _Plain({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Letra sin sincronizar',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lines.map((l) => l.text).join('\n'),
            style: theme.textTheme.titleLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoLyrics extends ConsumerWidget {
  const _NoLyrics({super.key});

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final song = ref.read(currentSongProvider).value;
    if (song == null) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Agregar letra'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 10,
          minLines: 5,
          decoration: const InputDecoration(
            hintText: 'Pega la letra aquí (texto o formato LRC con tiempos)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    await ref.read(lyricsSourceProvider).save(song, text);
    ref.invalidate(lyricsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CenteredMessage(
        'No encontramos la letra de esta canción',
        icon: AppIcons.lyrics,
      ),
      FilledButton.tonalIcon(
        onPressed: () => _paste(context, ref),
        icon: const AppIcon(AppIcons.edit, size: 18),
        label: const Text('Agregar letra'),
      ),
      const SizedBox(height: 80),
    ],
  );
}
