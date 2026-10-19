import 'dart:math';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/appearance/appearance.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/equalizer_screen.dart';
import 'package:sonaplay/features/player/presentation/screens/queue_screen.dart';

/// The current song's artwork, flying between the mini player and the player
/// (also while the player is dragged)
class NowPlayingHero extends StatelessWidget {
  final String songId;
  final Widget child;
  const NowPlayingHero({super.key, required this.songId, required this.child});

  @override
  Widget build(BuildContext context) => Hero(
    tag: 'now-playing-artwork',
    transitionOnUserGestures: true,
    // Redrawn at the in-flight size, so the corners stay round as it grows
    flightShuttleBuilder: (_, _, _, _, _) => LayoutBuilder(
      builder: (context, box) =>
          Artwork(songId: songId, size: box.maxWidth, large: true),
    ),
    child: child,
  );
}

/// Rises from the bottom. While dragged, the finger drives the route's own
/// animation, and on release a spring finishes the move at the finger's speed
/// (the same approach as the iOS back swipe).
class PlayerRoute extends PageRoute<void> {
  PlayerRoute();

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  // ponytail: the page below is composited the whole time the player is open;
  // flip the overlay entry to opaque between drags if that ever costs frames
  @override
  bool get opaque => false;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => Motion.slow;
  @override
  Duration get reverseTransitionDuration => Motion.medium;

  @override
  Widget buildPage(context, animation, secondaryAnimation) =>
      const PlayerScreen();

  @override
  Widget buildTransitions(context, animation, secondaryAnimation, child) =>
      ValueListenableBuilder(
        valueListenable: navigator!.userGestureInProgressNotifier,
        builder: (context, dragging, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            // Linear while dragging, so the page stays under the finger
            dragging
                ? animation
                : CurvedAnimation(
                    parent: animation,
                    curve: Motion.enter,
                    reverseCurve: Curves.easeInCubic,
                  ),
          ),
          child: child,
        ),
        child: child,
      );

  void dragStart() => navigator!.didStartUserGesture();

  /// [fraction] of the screen height moved down
  void dragUpdate(double fraction) => controller!.value -= fraction;

  /// [velocity] in screen heights per second, positive downwards
  void dragEnd(double velocity) {
    final controller = this.controller!;
    final close = velocity > 1.2 || (velocity > -1.2 && controller.value < 0.7);
    if (close) {
      navigator!.pop();
      // Replaces pop's default reverse with a spring at the finger's speed
      controller.fling(velocity: -velocity.clamp(1.5, 8.0));
    } else {
      controller.fling(velocity: (-velocity).clamp(1.5, 8.0));
    }
    if (controller.isAnimating) {
      late final AnimationStatusListener done;
      done = (status) {
        if (status.isAnimating) return;
        navigator?.didStopUserGesture();
        controller.removeStatusListener(done);
      };
      controller.addStatusListener(done);
    } else {
      navigator!.didStopUserGesture();
    }
  }
}

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
    final sleepEnds = ref.watch(sleepTimerProvider);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Shows while the artwork loads or when there is none (the route
          // is see-through so the page below can show while dragging)
          const AppBackground(child: SizedBox.expand()),
          _ArtworkBackdrop(songId: song.id),
          SafeArea(
            child: GestureDetector(
              // Drag down anywhere: the player follows the finger
              onVerticalDragStart: (_) => _route?.dragStart(),
              onVerticalDragUpdate: (d) =>
                  _route?.dragUpdate(d.primaryDelta! / context.size!.height),
              onVerticalDragEnd: (d) =>
                  _route?.dragEnd(d.primaryVelocity! / context.size!.height),
              onVerticalDragCancel: () => _route?.dragEnd(0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () => showSongOptions(context, song),
                        ),
                      ],
                    ),
                    Expanded(
                      child: GestureDetector(
                        // Swipe the artwork sideways to change song
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -300) player.skipToNext();
                          if (v > 300) player.skipToPrevious();
                        },
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final size = min(box.maxWidth, box.maxHeight - 32);
                            return Center(
                              child: NowPlayingHero(
                                songId: song.id,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: DecoratedBox(
                                    key: ValueKey(song.id),
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
                                  ),
                                ),
                              ),
                            );
                          },
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
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite ? scheme.primary : null,
                          ),
                          onPressed: () {
                            final favorites = ref.read(
                              favoritesDataSourceProvider,
                            );
                            isFavorite
                                ? favorites.removeFavorite(song.id)
                                : favorites.addFavorite(song.id);
                          },
                        ),
                      ],
                    ),
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
                          await player.seek(Duration(milliseconds: v.round()));
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
                          icon: Icons.shuffle_rounded,
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          tooltip: 'Anterior',
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: player.skipToPrevious,
                        ),
                        SizedBox.square(
                          dimension: 84,
                          child: IconButton.filled(
                            tooltip: state.isPlaying ? 'Pausar' : 'Reproducir',
                            iconSize: 44,
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  // Rounder while paused, like a play "button"
                                  state.isPlaying ? 26 : 42,
                                ),
                              ),
                            ),
                            icon: Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            onPressed: state.isPlaying
                                ? player.pause
                                : player.resume,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          iconSize: 40,
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BottomAction(
                          icon: Icons.equalizer_rounded,
                          label: 'Ecualizador',
                          onPressed: () => _open(const EqualizerScreen()),
                        ),
                        _BottomAction(
                          icon: Icons.bedtime_outlined,
                          label: sleepEnds == null
                              ? 'Temporizador'
                              : TimeOfDay.fromDateTime(sleepEnds)
                                    .format(context),
                          active: sleepEnds != null,
                          onPressed: () => pickSleepTimer(
                            context,
                            ProviderScope.containerOf(context, listen: false),
                          ),
                        ),
                        _BottomAction(
                          icon: Icons.queue_music_rounded,
                          label: 'Cola',
                          onPressed: () => _open(const QueueScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  final IconData icon;
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
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
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
