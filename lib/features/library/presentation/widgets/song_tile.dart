import 'package:flutter/material.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Smaller artwork and tighter rows, to fit more songs on screen
  final bool compact;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final artSize = compact ? 40.0 : 48.0;
    return Pressable(
      child: ListTile(
        selected: isCurrent,
        onTap: onTap,
        onLongPress: onLongPress,
        dense: compact,
        visualDensity: compact
            ? const VisualDensity(vertical: -2)
            : VisualDensity.standard,
        leading: Artwork(songId: song.id, size: artSize),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${song.artist} · ${song.formattedDuration}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The playing song is marked by the accent color (selected)
        trailing: IconButton(
          tooltip: 'Opciones de ${song.title}',
          icon: const AppIcon(AppIcons.more),
          onPressed: () => showSongOptions(context, song),
        ),
      ),
    );
  }
}

/// Card with large artwork, for the grid view
class SongGridTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SongGridTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        Artwork(songId: song.id, size: box.maxWidth),
                        if (isCurrent)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: scheme.primary,
                              child: AppIcon(
                                AppIcons.nowPlaying,
                                size: 18,
                                color: scheme.onPrimary,
                                semanticLabel: 'Sonando',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: isCurrent ? scheme.primary : null,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox.square(
                      dimension: 40,
                      child: IconButton(
                        tooltip: 'Opciones de ${song.title}',
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const AppIcon(AppIcons.more),
                        onPressed: () => showSongOptions(context, song),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
