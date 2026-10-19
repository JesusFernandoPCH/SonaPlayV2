import 'package:flutter/material.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Smaller artwork and tighter rows, to fit more songs on screen
  final bool compact;

  /// Null outside multi-select; otherwise whether this song is checked
  final bool? checked;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
    this.checked,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        tileColor: checked == true ? scheme.secondaryContainer : null,
        selectedTileColor: checked == true ? scheme.secondaryContainer : null,
        leading: checked == true
            ? CircleAvatar(
                radius: artSize / 2,
                backgroundColor: scheme.primary,
                child: Icon(Icons.check_rounded, color: scheme.onPrimary),
              )
            : Artwork(songId: song.id, size: artSize),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${song.artist} · ${song.formattedDuration}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // The playing song is marked by the accent color (selected)
        trailing: checked != null
            ? null
            : IconButton(
                tooltip: 'Opciones de ${song.title}',
                icon: const Icon(Icons.more_vert_rounded),
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
  final bool? checked;

  const SongGridTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onLongPress,
    this.checked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      child: Material(
        color: checked == true ? scheme.secondaryContainer : Colors.transparent,
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
                        if (checked == true)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(
                                  box.maxWidth * 0.16,
                                ),
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 40,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        if (isCurrent && checked != true)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: scheme.primary,
                              child: Icon(
                                Icons.graphic_eq_rounded,
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
                    if (checked == null)
                      SizedBox.square(
                        dimension: 40,
                        child: IconButton(
                          tooltip: 'Opciones de ${song.title}',
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.more_vert_rounded),
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
