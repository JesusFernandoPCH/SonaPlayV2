import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/domain/library_query.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
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
    final results = ref
        .watch(visibleSongsProvider)
        .whenData((songs) => searchSongs(songs, _query));
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
        child: _query.trim().isEmpty
            ? const CenteredMessage(
                'Escribe para buscar en tu biblioteca',
                icon: Icons.search_rounded,
              )
            // New key per query: the results slide in again as you type
            : SongListView(
                key: ValueKey(_query.trim()),
                songs: results,
                emptyText: 'Sin resultados para "${_query.trim()}"',
              ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
