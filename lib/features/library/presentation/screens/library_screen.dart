import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/folders_tab.dart';
import 'package:sonaplay/features/library/presentation/screens/playlists_tab.dart';
import 'package:sonaplay/features/library/presentation/screens/search_screen.dart';
import 'package:sonaplay/features/library/presentation/widgets/library_sheets.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final filtered = filter.artist != null || filter.album != null;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          actions: [
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Ordenar',
              icon: const Icon(Icons.sort_rounded),
              onPressed: () => showSortSheet(context),
            ),
            IconButton(
              tooltip: filtered ? 'Filtros activos' : 'Filtrar',
              isSelected: filtered,
              icon: const Icon(Icons.filter_list_rounded),
              selectedIcon: const Icon(Icons.filter_alt_rounded),
              onPressed: () => showFilterSheet(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Canciones'),
              Tab(text: 'Playlists'),
              Tab(text: 'Favoritos'),
              Tab(text: 'Carpetas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SongListView(
              songs: ref.watch(librarySongsProvider),
              emptyText: filtered
                  ? 'Ninguna canción coincide con los filtros'
                  : 'No encontramos canciones en este teléfono',
              banner: filtered ? _FilterChips(filter: filter) : null,
            ),
            const PlaylistsTab(),
            SongListView(
              songs: ref.watch(favoriteSongsProvider),
              emptyText:
                  'Toca el corazón en el reproductor para guardar favoritas',
            ),
            const FoldersTab(),
          ],
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  final LibraryFilter filter;
  const _FilterChips({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(libraryFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        children: [
          if (filter.artist case final artist?)
            InputChip(
              label: Text('Artista: $artist'),
              onDeleted: () =>
                  notifier.apply((artist: null, album: filter.album)),
            ),
          if (filter.album case final album?)
            InputChip(
              label: Text('Álbum: $album'),
              onDeleted: () =>
                  notifier.apply((artist: filter.artist, album: null)),
            ),
        ],
      ),
    );
  }
}
