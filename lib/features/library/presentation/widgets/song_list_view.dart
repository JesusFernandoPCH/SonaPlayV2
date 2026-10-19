import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/fast_scrollbar.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/selection_screen.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_tile.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/player_route.dart';

/// Song list with a "count · Reproducir · Aleatorio" header; handles loading,
/// error and empty states. Used by every tab and detail screen.
class SongListView extends ConsumerWidget {
  final AsyncValue<List<Song>> songs;
  final String emptyText;

  /// Shown above the header (e.g. active filter chips), also when empty
  final Widget? banner;

  const SongListView({
    super.key,
    required this.songs,
    required this.emptyText,
    this.banner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (songs) {
      AsyncData(:final value) when value.isEmpty => Column(
        children: [
          ?banner,
          Expanded(child: CenteredMessage(emptyText)),
        ],
      ),
      AsyncData(:final value) => _List(songs: value, banner: banner),
      AsyncError() => const CenteredMessage('No se pudo leer la música'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _List extends ConsumerStatefulWidget {
  final List<Song> songs;
  final Widget? banner;
  const _List({required this.songs, this.banner});

  @override
  ConsumerState<_List> createState() => _ListState();
}

class _ListState extends ConsumerState<_List> {
  /// Rows built right after the list appears slide in; later ones (scrolled
  /// into view) just show
  final _shownAt = DateTime.now();

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Song> get _songs => widget.songs;

  Future<void> _play(int index, {bool? shuffle}) async {
    final handler = ref.read(audioHandlerProvider);
    await handler.playSong(_songs[index], _songs, index);
    if (shuffle != null && handler.audioPlayer.isShuffled != shuffle) {
      await handler.audioPlayer.toggleShuffle();
    }
  }

  /// Long press: multi-select on its own screen, at the same scroll position
  void _select(Song song) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SelectionScreen(
        songs: _songs,
        initial: song.id,
        scrollOffset: _scroll.offset,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(currentSongProvider).value?.id;
    final view = ref.watch(libraryViewProvider);
    final animate = DateTime.now().difference(_shownAt) < Motion.slow * 2;

    Widget item(int index) {
      final song = _songs[index];
      final isCurrent = song.id == currentId;
      // The playing song opens the player instead of restarting
      final VoidCallback onTap = isCurrent
          ? () => Navigator.push(context, PlayerRoute())
          : () => _play(index);
      return Entrance(
        key: ValueKey(song.id),
        delay: staggerDelay(index),
        animate: animate,
        child: view == LibraryView.grid
            ? SongGridTile(
                song: song,
                isCurrent: isCurrent,
                onTap: onTap,
                onLongPress: () => _select(song),
              )
            : SongTile(
                song: song,
                isCurrent: isCurrent,
                compact: view == LibraryView.compact,
                onTap: onTap,
                onLongPress: () => _select(song),
              ),
      );
    }

    return FastScrollbar(
      controller: _scroll,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          if (widget.banner case final banner?)
            SliverToBoxAdapter(child: banner),
          SliverToBoxAdapter(child: _header(context)),
          if (view == LibraryView.grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.74,
                ),
                itemCount: _songs.length,
                itemBuilder: (_, i) => item(i),
              ),
            )
          else
            SliverList.builder(
              itemCount: _songs.length,
              itemBuilder: (_, i) => item(i),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _songs.length == 1 ? '1 canción' : '${_songs.length} canciones',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        FilledButton.icon(
          onPressed: () => _play(0, shuffle: false),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproducir'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () =>
              _play(Random().nextInt(_songs.length), shuffle: true),
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Aleatorio'),
        ),
      ],
    ),
  );
}

class CenteredMessage extends StatelessWidget {
  final String text;
  final IconData? icon;
  const CenteredMessage(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
          ],
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
