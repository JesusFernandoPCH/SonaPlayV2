import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_tile.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: switch (ref.watch(visibleSongsProvider)) {
        AsyncData(:final value) when value.isEmpty => const _Message(
          'No encontramos canciones en este teléfono',
        ),
        AsyncData(:final value) => _SongList(songs: value),
        AsyncError() => const _Message('No se pudo leer la música'),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _SongList extends ConsumerWidget {
  final List<Song> songs;
  const _SongList({required this.songs});

  Future<void> _play(WidgetRef ref, int index, {bool? shuffle}) async {
    final handler = ref.read(audioHandlerProvider);
    await handler.playSong(songs[index], songs, index);
    if (shuffle != null && handler.audioPlayer.isShuffled != shuffle) {
      await handler.audioPlayer.toggleShuffle();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(currentSongProvider).value?.id;
    return ListView.builder(
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${songs.length} canciones',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _play(ref, 0, shuffle: false),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      _play(ref, Random().nextInt(songs.length), shuffle: true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatorio'),
                ),
              ],
            ),
          );
        }
        final song = songs[i - 1];
        return SongTile(
          song: song,
          isCurrent: song.id == currentId,
          onTap: () => _play(ref, i - 1),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
