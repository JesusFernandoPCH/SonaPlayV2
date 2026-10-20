import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

const _rowHeight = 72.0;
const _reshuffle = Duration(milliseconds: 700);

/// Current queue: tap to jump, drag the handle to reorder
class QueueList extends ConsumerStatefulWidget {
  const QueueList({super.key});

  @override
  ConsumerState<QueueList> createState() => _QueueListState();
}

class _QueueListState extends ConsumerState<QueueList> {
  // Opens with the current song in view, two rows below the top
  late final _scroll = ScrollController(
    initialScrollOffset:
        ((ref.read(audioHandlerProvider).audioPlayer.currentIndex ?? 0) - 2)
            .clamp(0, 1 << 30) *
        _rowHeight,
  );

  /// Order at the last build, so rows can slide from where they were when
  /// shuffle is toggled
  Map<String, int> _lastIndex = {};
  bool? _lastShuffled;
  Map<String, int> _shift = {};
  var _generation = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The queue lives in the player; its state stream fires on every change
    ref.watch(playerStateProvider);
    ref.watch(currentSongProvider);
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final queue = player.currentPlaylist;
    final current = player.currentIndex;
    final shuffled = player.isShuffled;

    final index = {for (final (i, s) in queue.indexed) s.id: i};
    if (_lastShuffled != null && shuffled != _lastShuffled) {
      // At most a screen away, so far rows slide in instead of flashing by
      _shift = {
        for (final MapEntry(:key, :value) in index.entries)
          key: ((_lastIndex[key] ?? value) - value).clamp(-12, 12),
      };
      _generation++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          (((current ?? 0) - 2) * _rowHeight).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
          duration: _reshuffle,
          curve: Curves.easeInOutCubic,
        );
      });
    }
    _lastShuffled = shuffled;
    _lastIndex = index;

    return ReorderableListView.builder(
      itemCount: queue.length,
      scrollController: _scroll,
      itemExtent: _rowHeight,
      buildDefaultDragHandles: false,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      onReorderItem: (from, to) =>
          // reorderQueue expects the index before removal (old onReorder style)
          player.reorderQueue(from, to > from ? to + 1 : to),
      itemBuilder: (context, i) {
        final song = queue[i];
        final row = ListTile(
          selected: i == current,
          leading: Artwork(songId: song.id, size: 44),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ReorderableDragStartListener(
            index: i,
            child: const AppIcon(AppIcons.drag),
          ),
          onTap: () => player.skipToIndex(i),
        );
        final shift = _shift[song.id] ?? 0;
        return KeyedSubtree(
          key: ValueKey(song.id),
          child: shift == 0
              ? row
              : TweenAnimationBuilder<double>(
                  // New generation: starts again from the old position
                  key: ValueKey(_generation),
                  tween: Tween(begin: shift * _rowHeight, end: 0),
                  duration: _reshuffle,
                  curve: Curves.easeInOutCubic,
                  builder: (_, dy, child) =>
                      Transform.translate(offset: Offset(0, dy), child: child),
                  child: row,
                ),
        );
      },
    );
  }
}
