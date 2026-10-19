import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/player_screen.dart';

/// Bottom bar with the current song; hidden while nothing is queued
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    // Still reserves the system navigation bar inset so lists end above it
    if (song == null) return const SafeArea(top: false, child: SizedBox());

    final state = ref.watch(playerStateProvider).value;
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final scheme = Theme.of(context).colorScheme;
    final total = state?.duration.inMilliseconds ?? 0;
    final progress = total > 0 ? state!.position.inMilliseconds / total : 0.0;
    final isPlaying = state?.isPlaying ?? false;

    return Material(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.14),
        scheme.surfaceContainer,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Artwork(songId: song.id, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Anterior',
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: player.skipToPrevious,
                    ),
                    IconButton.filled(
                      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                      icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: isPlaying ? player.pause : player.resume,
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: player.skipToNext,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
