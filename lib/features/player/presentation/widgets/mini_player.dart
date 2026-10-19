import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/player_screen.dart';

/// Floating card with the current song; hidden while nothing is queued
class MiniPlayer extends ConsumerWidget {
  /// Sits on a navigation bar, which already keeps clear of the system bar
  final bool aboveNavigation;

  const MiniPlayer({super.key, this.aboveNavigation = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) {
      // Still reserves the system navigation bar inset so lists end above it
      return aboveNavigation
          ? const SizedBox.shrink()
          : const SafeArea(top: false, child: SizedBox());
    }

    final state = ref.watch(playerStateProvider).value;
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = state?.duration.inMilliseconds ?? 0;
    final progress = total > 0 ? state!.position.inMilliseconds / total : 0.0;
    final isPlaying = state?.isPlaying ?? false;

    final card = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Pressable(
        pressedScale: 0.98,
        child: Material(
          color: barColor(scheme),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, PlayerRoute()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                  child: Row(
                    children: [
                      NowPlayingHero(
                        songId: song.id,
                        child: Artwork(songId: song.id, size: 44),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        // The new song's name slides in when the track changes
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Column(
                            key: ValueKey(song.id),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return aboveNavigation ? card : SafeArea(top: false, child: card);
  }
}
