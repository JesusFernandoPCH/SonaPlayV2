import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Current queue: tap to jump, drag the handle to reorder
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The queue lives in the player; its state stream fires on every change
    ref.watch(playerStateProvider);
    ref.watch(currentSongProvider);
    final player = ref.watch(audioHandlerProvider).audioPlayer;
    final queue = player.currentPlaylist;
    final current = player.currentIndex;

    return Scaffold(
      appBar: AppBar(title: Text('Cola · ${queue.length}')),
      body: ReorderableListView.builder(
        itemCount: queue.length,
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        onReorderItem: (from, to) =>
            // reorderQueue expects the index before removal (old onReorder style)
            player.reorderQueue(from, to > from ? to + 1 : to),
        itemBuilder: (context, i) {
          final song = queue[i];
          return ListTile(
            key: ValueKey(song.id),
            selected: i == current,
            leading: Artwork(songId: song.id, size: 44),
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
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle_rounded),
            ),
            onTap: () => player.skipToIndex(i),
          );
        },
      ),
    );
  }
}
