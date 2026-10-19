import 'package:flutter/material.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Null outside multi-select; otherwise whether this song is checked
  final bool? checked;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
    this.onLongPress,
    this.checked,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: isCurrent,
      onTap: onTap,
      onLongPress: onLongPress,
      tileColor: checked == true ? scheme.secondaryContainer : null,
      selectedTileColor: checked == true ? scheme.secondaryContainer : null,
      leading: checked == true
          ? CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primary,
              child: Icon(Icons.check_rounded, color: scheme.onPrimary),
            )
          : Artwork(songId: song.id),
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
    );
  }
}
