import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/player_route.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

/// Size and corner of the card, which the player morphs into when it closes
const kMiniPlayerRadius = 18.0;
const kMiniArtworkInset = Offset(8, 8);
const kMiniArtworkSize = 44.0;

/// Floating card with the current song; hidden while nothing is queued
class MiniPlayer extends ConsumerWidget {
  /// Sits on a navigation bar, which already keeps clear of the system bar
  final bool aboveNavigation;

  const MiniPlayer({super.key, this.aboveNavigation = false});

  /// Where the card on the visible screen is, so the player can open from it
  /// and close into it
  static Rect? lastRect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) {
      // Still reserves the system navigation bar inset so lists end above it
      return aboveNavigation
          ? const SizedBox.shrink()
          : const SafeArea(top: false, child: SizedBox());
    }

    final card = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Builder(
        builder: (cardContext) {
          // Measured outside Pressable, so the press shrink doesn't skew it
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!cardContext.mounted) return;
            if (ModalRoute.of(cardContext)?.isCurrent != true) return;
            final box = cardContext.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;
            lastRect = box.localToGlobal(Offset.zero) & box.size;
          });
          return Pressable(
            pressedScale: 0.98,
            child: Material(
              color: barColor(Theme.of(context).colorScheme),
              borderRadius: BorderRadius.circular(kMiniPlayerRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(context, PlayerRoute()),
                child: MiniPlayerContent(
                  artwork: Artwork(songId: song.id, size: kMiniArtworkSize),
                ),
              ),
            ),
          );
        },
      ),
    );

    return aboveNavigation ? card : SafeArea(top: false, child: card);
  }
}

/// The card's row and progress line; also drawn by the player while it
/// shrinks into the card
class MiniPlayerContent extends ConsumerWidget {
  final Widget artwork;
  const MiniPlayerContent({super.key, required this.artwork});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) return const SizedBox.shrink();
    final state = ref.watch(playerStateProvider).value;
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = state?.duration.inMilliseconds ?? 0;
    final progress = total > 0 ? state!.position.inMilliseconds / total : 0.0;
    final isPlaying = state?.isPlaying ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            kMiniArtworkInset.dx,
            kMiniArtworkInset.dy,
            4,
            6,
          ),
          child: Row(
            children: [
              artwork,
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
                icon: const AppIcon(AppIcons.previous, filled: true),
                onPressed: player.skipToPrevious,
              ),
              IconButton.filled(
                tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                icon: SwapIcon(
                  isPlaying ? AppIcons.pause : AppIcons.play,
                  filled: true,
                ),
                onPressed: isPlaying ? player.pause : player.resume,
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const AppIcon(AppIcons.next, filled: true),
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
    );
  }
}
