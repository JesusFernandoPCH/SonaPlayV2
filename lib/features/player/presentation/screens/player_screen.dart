import 'dart:math';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/equalizer_screen.dart';
import 'package:sonaplay/features/player/presentation/screens/queue_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  /// Slider position while the user drags, so it doesn't jump back
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider).value;
    final state = ref.watch(playerStateProvider).value ?? const PlayerState();
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final isFavorite =
        song != null &&
        (ref.watch(favoriteIdsProvider).value?.contains(song.id) ?? false);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Nada en reproducción')));
    }

    final totalMs = max(state.duration.inMilliseconds.toDouble(), 1.0);
    final positionMs = (_dragMs ?? state.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.28),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Reproduciendo',
                        textAlign: TextAlign.center,
                        style: text.labelLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cola',
                      icon: const Icon(Icons.queue_music_rounded),
                      onPressed: () => _open(const QueueScreen()),
                    ),
                    IconButton(
                      tooltip: 'Opciones de la canción',
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () => showSongOptions(context, song),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Center(
                      child: Artwork(
                        songId: song.id,
                        size: min(box.maxWidth, box.maxHeight - 24),
                        large: true,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge,
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite
                          ? 'Quitar de favoritos'
                          : 'Agregar a favoritos',
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? scheme.primary : null,
                      ),
                      onPressed: () {
                        final favorites = ref.read(favoritesDataSourceProvider);
                        isFavorite
                            ? favorites.removeFavorite(song.id)
                            : favorites.addFavorite(song.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: positionMs,
                  max: totalMs,
                  onChanged: (v) => setState(() => _dragMs = v),
                  onChangeEnd: (v) async {
                    await player.seek(Duration(milliseconds: v.round()));
                    setState(() => _dragMs = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(positionMs), style: text.bodySmall),
                      Text(_format(totalMs), style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ModeButton(
                      active: state.isShuffled,
                      tooltip: state.isShuffled
                          ? 'Aleatorio activado'
                          : 'Aleatorio desactivado',
                      icon: Icons.shuffle_rounded,
                      onPressed: player.toggleShuffle,
                    ),
                    IconButton(
                      tooltip: 'Anterior',
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: player.skipToPrevious,
                    ),
                    IconButton.filled(
                      tooltip: state.isPlaying ? 'Pausar' : 'Reproducir',
                      iconSize: 44,
                      padding: const EdgeInsets.all(16),
                      icon: Icon(
                        state.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: state.isPlaying ? player.pause : player.resume,
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: player.skipToNext,
                    ),
                    _ModeButton(
                      active: state.repeatMode != RepeatMode.off,
                      tooltip: switch (state.repeatMode) {
                        RepeatMode.all => 'Repetir todas',
                        RepeatMode.one => 'Repetir una',
                        RepeatMode.off => 'Repetir desactivado',
                      },
                      icon: state.repeatMode == RepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      onPressed: () =>
                          player.setRepeatMode(switch (state.repeatMode) {
                            RepeatMode.all => RepeatMode.one,
                            RepeatMode.one => RepeatMode.off,
                            RepeatMode.off => RepeatMode.all,
                          }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _open(const EqualizerScreen()),
                      icon: const Icon(Icons.equalizer_rounded),
                      label: const Text('Ecualizador'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  static String _format(double ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Shuffle/repeat toggle: a tonal background marks it as on, so the state
/// reads even when the artwork accent is close to white
class _ModeButton extends StatelessWidget {
  final bool active;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.active,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return active
        ? IconButton.filledTonal(
            tooltip: tooltip,
            icon: Icon(icon),
            onPressed: onPressed,
          )
        : IconButton(
            tooltip: tooltip,
            icon: Icon(icon),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: onPressed,
          );
  }
}
