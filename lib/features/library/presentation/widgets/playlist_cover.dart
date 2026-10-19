import 'package:flutter/material.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';

/// Square cover: the first song's artwork, or a 2x2 collage with 4+ songs
class PlaylistCover extends StatelessWidget {
  final List<Song> songs;
  final double size;

  const PlaylistCover({super.key, required this.songs, this.size = 56});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.16),
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Icon(
              Icons.queue_music_rounded,
              size: size * 0.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (songs.length < 4) return Artwork(songId: songs.first.id, size: size);

    final half = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final song in songs.take(4))
              // Square tiles; the outer clip rounds the collage corners
              ClipRect(
                child: Artwork(songId: song.id, size: half),
              ),
          ],
        ),
      ),
    );
  }
}
