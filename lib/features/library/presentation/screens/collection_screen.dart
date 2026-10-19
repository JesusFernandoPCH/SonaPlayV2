import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/playlist_cover.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

/// A group of songs (playlist, folder, artist, album) under a large header
class CollectionScreen extends StatelessWidget {
  /// "Playlist", "Carpeta", "Artista"...
  final String kind;
  final String title;
  final AsyncValue<List<Song>> songs;
  final String emptyText;
  final List<Widget> actions;

  /// Round cover, the convention for artists
  final bool round;

  const CollectionScreen({
    super.key,
    required this.kind,
    required this.title,
    required this.songs,
    required this.emptyText,
    this.actions = const [],
    this.round = false,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: actions),
    body: SongListView(
      songs: songs,
      emptyText: emptyText,
      banner: _Header(
        kind: kind,
        title: title,
        songs: songs.value ?? const [],
        round: round,
      ),
    ),
    bottomNavigationBar: const MiniPlayer(),
  );
}

class _Header extends StatelessWidget {
  final String kind;
  final String title;
  final List<Song> songs;
  final bool round;

  const _Header({
    required this.kind,
    required this.title,
    required this.songs,
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes =
        songs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)) ~/ 60000;
    const size = 200.0;

    return Entrance(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(size * 0.16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: round && songs.isNotEmpty
                  ? ClipOval(
                      child: Artwork(
                        songId: songs.first.id,
                        size: size,
                        large: true,
                        square: true,
                      ),
                    )
                  : PlaylistCover(songs: songs, size: size),
            ),
            const SizedBox(height: 20),
            Text(
              kind.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${songs.length == 1 ? '1 canción' : '${songs.length} canciones'}'
              ' · ${minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
