import 'package:flutter/material.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

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
            child: AppIcon(
              AppIcons.queue,
              size: size * 0.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // Sharper artwork only for big tiles; a collage tile is half the cover
    final large = (songs.length < 4 ? size : size / 2) > 100;
    if (songs.length < 4) {
      return Artwork(songId: songs.first.id, size: size, large: large);
    }

    final half = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final song in songs.take(4))
              // Square tiles; the outer clip rounds the collage corners
              Artwork(songId: song.id, size: half, square: true, large: large),
          ],
        ),
      ),
    );
  }
}
