import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/player_screen.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

/// The player and the mini player are one piece: opening stretches the card
/// into the full player and closing squeezes it back, with the artwork
/// travelling between its two places. While dragged, the finger drives the
/// route's own animation; on release it eases on from the finger's speed.
class PlayerRoute extends PageRoute<void> {
  PlayerRoute();

  /// The player's big artwork, measured to start/end the flying artwork
  final artworkKey = GlobalKey();
  final _contentKey = GlobalKey();

  static const _duration = Duration(milliseconds: 620);
  static const _curve = Curves.easeInOutCubic;

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
  Duration get transitionDuration => _duration;
  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  Widget buildPage(context, animation, secondaryAnimation) =>
      KeyedSubtree(key: _contentKey, child: const PlayerScreen());

  /// The card the player opens from and closes into
  Rect _card(Size screen) =>
      MiniPlayer.lastRect ??
      Rect.fromLTWH(8, screen.height - 150, screen.width - 16, 64);

  /// The big artwork in the player's own (unscaled) coordinates
  Rect? _artworkRect() {
    final art = artworkKey.currentContext?.findRenderObject() as RenderBox?;
    final root = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (art == null || root == null || !art.attached || !art.hasSize) {
      return null;
    }
    return art.localToGlobal(Offset.zero, ancestor: root) & art.size;
  }

  @override
  Widget buildTransitions(context, animation, secondaryAnimation, child) =>
      ValueListenableBuilder(
        valueListenable: navigator!.userGestureInProgressNotifier,
        builder: (context, dragging, child) {
          // Linear while dragging, so the edge stays under the finger
          final progress = dragging
              ? animation
              : CurvedAnimation(parent: animation, curve: _curve);
          return AnimatedBuilder(
            animation: progress,
            builder: (context, child) =>
                _morph(context, (1 - progress.value).clamp(0.0, 1.0), child!),
            child: child,
          );
        },
        child: child,
      );

  /// [p]: 0 is the full player, 1 is the mini player card
  Widget _morph(BuildContext context, double p, Widget player) {
    if (p == 0) return player;
    final screen = MediaQuery.sizeOf(context);
    final card = _card(screen);
    final rect = Rect.lerp(Offset.zero & screen, card, p)!;
    final art = _artworkRect();
    final cardArt =
        (card.topLeft + kMiniArtworkInset) &
        const Size.square(kMiniArtworkSize);

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              lerpDouble(0, kMiniPlayerRadius, min(1, p * 3))!,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Opaque: the page below must not show through the piece
                ColoredBox(
                  color: Color.alphaBlend(
                    barColor(Theme.of(context).colorScheme),
                    Colors.black,
                  ),
                ),
                // The card's content takes over towards the end
                Opacity(
                  opacity: ((p - 0.55) / 0.45).clamp(0.0, 1.0),
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: MiniPlayerContent(
                      artwork: SizedBox.square(dimension: kMiniArtworkSize),
                    ),
                  ),
                ),
                // The player keeps its full-size layout and is squeezed into
                // the shrinking shape, like dough, fading as it gets small
                Opacity(
                  opacity: (1 - (p - 0.25) / 0.4).clamp(0.0, 1.0),
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: screen.width,
                    maxWidth: screen.width,
                    minHeight: screen.height,
                    maxHeight: screen.height,
                    child: Transform(
                      transform: Matrix4.diagonal3Values(
                        rect.width / screen.width,
                        rect.height / screen.height,
                        1,
                      ),
                      child: player,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (art != null)
          Positioned.fromRect(
            rect: Rect.lerp(art, cardArt, p)!,
            child: Consumer(
              builder: (context, ref, _) {
                final id = ref.watch(currentSongProvider).value?.id;
                return LayoutBuilder(
                  builder: (context, box) => id == null
                      ? const SizedBox()
                      : Artwork(songId: id, size: box.maxWidth, large: true),
                );
              },
            ),
          ),
      ],
    );
  }

  /// How far the top edge travels between player and card
  double get _travel {
    final card = MiniPlayer.lastRect;
    final screen = navigator!.context.size!;
    return (card?.top ?? screen.height - 150).clamp(1, double.infinity);
  }

  void dragStart() => navigator!.didStartUserGesture();

  /// [delta] in pixels, positive downwards
  void dragUpdate(double delta) => controller!.value -= delta / _travel;

  /// [velocity] in pixels per second, positive downwards
  void dragEnd(double velocity) {
    final controller = this.controller!;
    final v = velocity / _travel;
    final close = v > 1.2 || (v > -1.2 && controller.value < 0.75);
    // Unhurried, quicker only for a fast flick
    final speedUp = 1 + v.abs().clamp(0.0, 6.0) / 3;
    if (close) {
      navigator!.pop();
      // Replaces pop's default reverse, continuing from where the finger left
      controller.animateBack(
        0,
        duration: Duration(
          milliseconds: (720 * controller.value / speedUp)
              .clamp(360, 720)
              .round(),
        ),
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.animateTo(
        1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
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
