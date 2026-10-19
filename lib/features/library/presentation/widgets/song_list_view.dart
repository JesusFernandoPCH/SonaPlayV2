import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_tile.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

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

class _List extends ConsumerWidget {
  final List<Song> songs;
  final Widget? banner;
  const _List({required this.songs, this.banner});

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
    final headerCount = banner == null ? 1 : 2;
    return ListView.builder(
      itemCount: songs.length + headerCount,
      itemBuilder: (context, i) {
        if (banner != null && i == 0) return banner!;
        if (i == headerCount - 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    songs.length == 1
                        ? '1 canción'
                        : '${songs.length} canciones',
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
        final index = i - headerCount;
        final song = songs[index];
        return SongTile(
          song: song,
          isCurrent: song.id == currentId,
          onTap: () => _play(ref, index),
        );
      },
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
