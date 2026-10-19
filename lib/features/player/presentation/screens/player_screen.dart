import 'dart:math';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/appearance/appearance.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/player/presentation/player_route.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/equalizer_screen.dart';
import 'package:sonaplay/features/player/presentation/widgets/queue_list.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  /// Slider position while the user drags, so it doesn't jump back
  double? _dragMs;

  /// 0: player, 1: queue on top with the player collapsed to a bar
  late final _queue = AnimationController(vsync: this, duration: Motion.slow);
  late final _queueCurve = CurvedAnimation(
    parent: _queue,
    curve: Motion.enter,
    reverseCurve: Motion.enter.flipped,
  );
  var _queueOpen = false;

  void _showQueue(bool open) {
    setState(() => _queueOpen = open);
    open ? _queue.forward() : _queue.reverse();
  }

  @override
  void dispose() {
    _queueCurve.dispose();
    _queue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider).value;
    final state = ref.watch(playerStateProvider).value ?? const PlayerState();
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final sleepEnds = ref.watch(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Nada en reproducción')));
    }

    final totalMs = max(state.duration.inMilliseconds.toDouble(), 1.0);
    final positionMs = (_dragMs ?? state.position.inMilliseconds.toDouble())
        .clamp(0.0, totalMs);

    return PopScope(
      // Back closes the queue first
      canPop: !_queueOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showQueue(false);
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Shows while the artwork loads or when there is none (the route
            // is see-through so the page below can show while dragging)
            const AppBackground(child: SizedBox.expand()),
            _ArtworkBackdrop(songId: song.id),
            // Recedes while the queue is up
            AnimatedBuilder(
              animation: _queueCurve,
              builder: (context, child) {
                final t = _queueCurve.value;
                return IgnorePointer(
                  ignoring: t > 0,
                  child: Opacity(
                    opacity: (1 - t * 1.5).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 - 0.08 * t,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: SafeArea(
                child: GestureDetector(
                  // Drag down anywhere, gaps included: the player follows the finger
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => _route?.dragStart(),
                  onVerticalDragUpdate: (d) =>
                      _route?.dragUpdate(d.primaryDelta!),
                  onVerticalDragEnd: (d) => _route?.dragEnd(d.primaryVelocity!),
                  onVerticalDragCancel: () => _route?.dragEnd(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Cerrar',
                              icon: const AppIcon(AppIcons.collapse),
                              iconSize: 32,
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'REPRODUCIENDO',
                                textAlign: TextAlign.center,
                                style: text.labelMedium?.copyWith(
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Opciones de la canción',
                              icon: const AppIcon(AppIcons.more),
                              onPressed: () => showSongOptions(context, song),
                            ),
                          ],
                        ),
                        // Artwork and title: swipe sideways anywhere here
                        // to move through the queue
                        Expanded(child: _SongCarousel(route: _route)),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            inactiveTrackColor: scheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Slider(
                            value: positionMs,
                            max: totalMs,
                            onChanged: (v) => setState(() => _dragMs = v),
                            onChangeEnd: (v) async {
                              await player.seek(
                                Duration(milliseconds: v.round()),
                              );
                              setState(() => _dragMs = null);
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_format(positionMs), style: text.bodySmall),
                            Text(_format(totalMs), style: text.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ModeButton(
                              active: state.isShuffled,
                              tooltip: state.isShuffled
                                  ? 'Aleatorio activado'
                                  : 'Aleatorio desactivado',
                              icon: AppIcons.shuffle,
                              onPressed: player.toggleShuffle,
                            ),
                            IconButton(
                              tooltip: 'Anterior',
                              iconSize: 40,
                              icon: const AppIcon(
                                AppIcons.previous,
                                filled: true,
                              ),
                              onPressed: player.skipToPrevious,
                            ),
                            SizedBox.square(
                              dimension: 84,
                              child: IconButton.filled(
                                tooltip: state.isPlaying
                                    ? 'Pausar'
                                    : 'Reproducir',
                                iconSize: 44,
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      // Rounder while paused, like a play "button"
                                      state.isPlaying ? 26 : 42,
                                    ),
                                  ),
                                ),
                                icon: SwapIcon(
                                  state.isPlaying
                                      ? AppIcons.pause
                                      : AppIcons.play,
                                  filled: true,
                                ),
                                onPressed: state.isPlaying
                                    ? player.pause
                                    : player.resume,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Siguiente',
                              iconSize: 40,
                              icon: const AppIcon(AppIcons.next, filled: true),
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
                                  ? AppIcons.repeatOne
                                  : AppIcons.repeat,
                              onPressed: () => player.setRepeatMode(
                                switch (state.repeatMode) {
                                  RepeatMode.all => RepeatMode.one,
                                  RepeatMode.one => RepeatMode.off,
                                  RepeatMode.off => RepeatMode.all,
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BottomAction(
                              icon: AppIcons.equalizer,
                              label: 'Ecualizador',
                              onPressed: () => _open(const EqualizerScreen()),
                            ),
                            _BottomAction(
                              icon: AppIcons.sleep,
                              label: sleepEnds == null
                                  ? 'Temporizador'
                                  : TimeOfDay.fromDateTime(sleepEnds)
                                        .format(context),
                              active: sleepEnds != null,
                              onPressed: () => pickSleepTimer(
                                context,
                                ProviderScope.containerOf(
                                  context,
                                  listen: false,
                                ),
                              ),
                            ),
                            _BottomAction(
                              icon: AppIcons.queue,
                              label: 'Cola',
                              onPressed: () => _showQueue(true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _queueCurve,
              builder: (context, _) {
                final t = _queueCurve.value;
                if (t == 0) return const SizedBox.shrink();
                return SafeArea(
                  child: Column(
                    children: [
                      Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, -24 * (1 - t)),
                          child: _CollapsedPlayer(
                            onExpand: () => _showQueue(false),
                          ),
                        ),
                      ),
                      Expanded(
                        // Rises from the bottom, where the Cola button is
                        child: FractionalTranslation(
                          translation: Offset(0, 1 - t),
                          child: const _QueuePanel(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  PlayerRoute? get _route => ModalRoute.of(context) as PlayerRoute?;

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  static String _format(double ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// The artwork stretched over the whole screen and darkened. Decoded at 32px
/// and scaled up, which blurs it for free (a real blur filter would be redone
/// on every progress tick).
class _ArtworkBackdrop extends ConsumerWidget {
  final String songId;
  const _ArtworkBackdrop({required this.songId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(artworkProvider(songId)).value;
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: Stack(
          key: ValueKey(bytes == null ? 'none' : songId),
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: 32,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bytes == null
                      // No artwork: an accent glow over the app background
                      ? [
                          scheme.primary.withValues(alpha: 0.25),
                          Colors.transparent,
                        ]
                      : [
                          // Darker at the top too, so the header reads over
                          // light artwork
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.85),
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

class _BottomAction extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
      icon: AppIcon(icon, size: 20),
      label: Text(label),
    );
  }
}

/// Shuffle/repeat toggle: a tonal background marks it as on, so the state
/// reads even when the artwork accent is close to white
class _ModeButton extends StatelessWidget {
  final bool active;
  final String tooltip;
  final AppIconData icon;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.active,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // One button whose background fades in, and whose icon spins once as it
    // turns on (and swaps with a pop, e.g. repeat to repeat-one)
    return IconButton(
      tooltip: tooltip,
      isSelected: active,
      onPressed: onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondaryContainer
              : Colors.transparent,
        ),
        animationDuration: Motion.medium,
      ),
      icon: AnimatedRotation(
        turns: active ? 1 : 0,
        duration: Motion.slow,
        curve: Motion.settle,
        child: SwapIcon(icon),
      ),
    );
  }
}

/// The player shrunk to a bar above the queue; tapping it brings it back
class _CollapsedPlayer extends ConsumerWidget {
  final VoidCallback onExpand;
  const _CollapsedPlayer({required this.onExpand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    final isPlaying = ref.watch(playerStateProvider).value?.isPlaying ?? false;
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final theme = Theme.of(context);
    if (song == null) return const SizedBox.shrink();
    return InkWell(
      onTap: onExpand,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Row(
          children: [
            Artwork(songId: song.id, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
              tooltip: 'Volver al reproductor',
              icon: const AppIcon(AppIcons.collapse),
              onPressed: onExpand,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuePanel extends ConsumerWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerStateProvider);
    final count = ref
        .watch(audioHandlerProvider)
        .audioPlayer
        .currentPlaylist
        .length;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.94),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              count == 1 ? 'Cola · 1 canción' : 'Cola · $count canciones',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Expanded(child: QueueList()),
        ],
      ),
    );
  }
}

/// Shows [child] only once the player is fully open
class _HiddenWhileMorphing extends StatelessWidget {
  final Widget child;
  const _HiddenWhileMorphing({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) =>
          Opacity(opacity: animation.value >= 1 ? 1 : 0, child: child),
      child: child,
    );
  }
}

/// The queue as pages of artwork and title. Neighbours slide in under the
/// finger; the song changes once the swipe settles on a page.
class _SongCarousel extends ConsumerStatefulWidget {
  final PlayerRoute? route;
  const _SongCarousel({required this.route});

  @override
  ConsumerState<_SongCarousel> createState() => _SongCarouselState();
}

class _SongCarouselState extends ConsumerState<_SongCarousel> {
  late final _pages = PageController(
    initialPage: ref.read(audioHandlerProvider).audioPlayer.currentIndex ?? 0,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _follow(int? index) {
    if (index == null || !_pages.hasClients) return;
    final shown = _pages.page?.round() ?? index;
    if (shown == index) return;
    // Next/previous glide over; bigger jumps (reorder, new queue) just cut
    (shown - index).abs() == 1
        ? _pages.animateToPage(
            index,
            duration: Motion.slow,
            curve: Motion.enter,
          )
        : _pages.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerStateProvider);
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final queue = player.currentPlaylist;
    final current = player.currentIndex;
    // Track the playing song's position, which also moves when the queue
    // changes under it (shuffle, reorder); never while the user is swiping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      if (_pages.position.isScrollingNotifier.value) return;
      _follow(player.currentIndex);
    });
    final favorites = ref.watch(favoriteIdsProvider).value ?? const {};
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        final page = _pages.page?.round();
        if (page != null && page != player.currentIndex) {
          player.skipToIndex(page);
        }
        return false;
      },
      // Full width (past the screen padding) so pages slide edge to edge
      child: LayoutBuilder(
        builder: (context, box) => OverflowBox(
          minWidth: box.maxWidth + 48,
          maxWidth: box.maxWidth + 48,
          child: PageView.builder(
            controller: _pages,
            itemCount: queue.length,
            itemBuilder: (context, i) {
              final song = queue[i];
              final isFavorite = favorites.contains(song.id);
              return AnimatedBuilder(
                animation: _pages,
                // Pages away from the centre shrink a little
                builder: (context, child) {
                  final page =
                      _pages.hasClients && _pages.position.hasContentDimensions
                      ? _pages.page ?? i.toDouble()
                      : (current ?? 0).toDouble();
                  final away = (page - i).abs().clamp(0.0, 1.0);
                  return Transform.scale(scale: 1 - 0.1 * away, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final size = min(box.maxWidth, box.maxHeight - 32);
                            final artwork = DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  size * 0.16,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 48,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Artwork(
                                songId: song.id,
                                size: size,
                                large: true,
                              ),
                            );
                            return Center(
                              // The playing song's artwork is measured by the
                              // route and hidden while its copy flies
                              child: i == current
                                  ? _HiddenWhileMorphing(
                                      key: widget.route?.artworkKey,
                                      child: artwork,
                                    )
                                  : artwork,
                            );
                          },
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
                                  style: text.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
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
                            iconSize: 28,
                            // Pops in filled when added
                            icon: SwapIcon(
                              AppIcons.favorite,
                              filled: isFavorite,
                              color: isFavorite ? scheme.primary : null,
                            ),
                            onPressed: () {
                              final store = ref.read(
                                favoritesDataSourceProvider,
                              );
                              isFavorite
                                  ? store.removeFavorite(song.id)
                                  : store.addFavorite(song.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
