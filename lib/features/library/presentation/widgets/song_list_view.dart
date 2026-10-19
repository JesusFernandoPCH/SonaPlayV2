import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/fast_scrollbar.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_tile.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/screens/player_screen.dart';

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
  /// IDs checked in multi-select; empty means normal mode
  final _selected = <String>{};

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

  void _toggle(Song song) => setState(
    () => _selected.contains(song.id)
        ? _selected.remove(song.id)
        : _selected.add(song.id),
  );

  @override
  void didUpdateWidget(_List old) {
    super.didUpdateWidget(old);
    // Songs that left the list (hidden, deleted, filtered) can't stay checked
    final ids = {for (final s in _songs) s.id};
    _selected.retainWhere(ids.contains);
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(currentSongProvider).value?.id;
    final view = ref.watch(libraryViewProvider);
    final selecting = _selected.isNotEmpty;
    final animate = DateTime.now().difference(_shownAt) < Motion.slow * 2;

    Widget item(int index) {
      final song = _songs[index];
      final isCurrent = song.id == currentId;
      final checked = selecting ? _selected.contains(song.id) : null;
      final VoidCallback onTap = selecting
          ? () => _toggle(song)
          // The playing song opens the player instead of restarting
          : isCurrent
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
                checked: checked,
                onTap: onTap,
                onLongPress: () => _toggle(song),
              )
            : SongTile(
                song: song,
                isCurrent: isCurrent,
                compact: view == LibraryView.compact,
                checked: checked,
                onTap: onTap,
                onLongPress: () => _toggle(song),
              ),
      );
    }

    return PopScope(
      // Back leaves multi-select before leaving the screen
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: FastScrollbar(
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
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
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
            ),
          ),
          // Pinned over the top (not above the list, which would shift the
          // rows under the finger) so it stays reachable while scrolling
          if (selecting)
            Positioned(top: 0, left: 0, right: 0, child: _selectionBar()),
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

  Widget _selectionBar() {
    final container = ProviderScope.containerOf(context, listen: false);
    final allChecked = _selected.length == _songs.length;

    /// Runs [action] on the checked songs (in list order) and leaves multi-select
    void run(Future<void> Function(List<Song> songs) action) {
      final songs = [
        for (final s in _songs)
          if (_selected.contains(s.id)) s,
      ];
      setState(_selected.clear);
      action(songs);
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancelar selección',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(_selected.clear),
          ),
          Expanded(
            child: Text(
              '${_selected.length} seleccionadas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: allChecked ? 'Quitar selección' : 'Seleccionar todo',
            icon: Icon(
              allChecked ? Icons.deselect_rounded : Icons.select_all_rounded,
            ),
            onPressed: () => setState(
              () => allChecked
                  ? _selected.clear()
                  : _selected.addAll(_songs.map((s) => s.id)),
            ),
          ),
          IconButton(
            tooltip: 'Agregar a playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () =>
                run((songs) => addSongsToPlaylist(context, container, songs)),
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => run(shareSongs),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            onSelected: (action) => run(
              (songs) => switch (action) {
                'next' => playSongsNext(context, container, songs),
                'hide' => hideSongs(context, songs),
                _ => trashSongs(context, songs),
              },
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'next',
                child: Text('Reproducir a continuación'),
              ),
              PopupMenuItem(value: 'hide', child: Text('Ocultar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
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
