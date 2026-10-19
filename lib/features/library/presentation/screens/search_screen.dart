import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/domain/library_query.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/collection_screen.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(visibleSongsProvider);
    final songs = library.value ?? const <Song>[];
    final results = searchLibrary(songs, _query);
    final query = _query.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Canción, artista o álbum',
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
      ),
      body: AnimatedSwitcher(
        duration: Motion.medium,
        child: query.isEmpty
            ? const CenteredMessage(
                'Escribe para buscar en tu biblioteca',
                icon: AppIcons.search,
              )
            // New key per query: the results slide in again as you type
            : SongListView(
                key: ValueKey(query),
                songs: library.whenData((_) => results.songs),
                emptyText: 'Sin resultados para "$query"',
                banner: results.artists.isEmpty && results.albums.isEmpty
                    ? null
                    : _Groups(results: results, library: songs),
              ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// Matching artists and albums as horizontal rows above the songs
class _Groups extends StatelessWidget {
  final SearchResults results;
  final List<Song> library;
  const _Groups({required this.results, required this.library});

  void _open(
    BuildContext context, {
    required String kind,
    required String title,
    required List<Song> songs,
    bool round = false,
  }) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CollectionScreen(
        kind: kind,
        title: title,
        songs: AsyncData(songs),
        emptyText: 'Sin canciones',
        round: round,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget row(String label, List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: items,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (results.artists.isNotEmpty)
          row('Artistas', [
            for (final (i, artist) in results.artists.indexed)
              Entrance(
                delay: staggerDelay(i),
                child: _GroupItem(
                  label: artist,
                  songs: filterSongs(library, artist: artist),
                  round: true,
                  onTap: (songs) => _open(
                    context,
                    kind: 'Artista',
                    title: artist,
                    songs: songs,
                    round: true,
                  ),
                ),
              ),
          ]),
        if (results.albums.isNotEmpty)
          row('Álbumes', [
            for (final (i, album) in results.albums.indexed)
              Entrance(
                delay: staggerDelay(i),
                child: _GroupItem(
                  label: album,
                  songs: filterSongs(library, album: album),
                  onTap: (songs) =>
                      _open(context, kind: 'Álbum', title: album, songs: songs),
                ),
              ),
          ]),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GroupItem extends StatelessWidget {
  final String label;
  final List<Song> songs;
  final bool round;
  final void Function(List<Song> songs) onTap;

  const _GroupItem({
    required this.label,
    required this.songs,
    required this.onTap,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final theme = Theme.of(context);
    return Pressable(
      child: InkWell(
        onTap: () => onTap(songs),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size + 8,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                if (songs.isNotEmpty)
                  round
                      ? ClipOval(
                          child: Artwork(
                            songId: songs.first.id,
                            size: size,
                            square: true,
                          ),
                        )
                      : Artwork(songId: songs.first.id, size: size),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
