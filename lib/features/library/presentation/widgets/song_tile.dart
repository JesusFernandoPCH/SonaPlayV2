import 'package:flutter/material.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final VoidCallback onTap;

  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: isCurrent,
      onTap: onTap,
      leading: Artwork(songId: song.id),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist} · ${song.formattedDuration}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // The playing song is marked by the accent color (selected)
      trailing: IconButton(
        tooltip: 'Opciones de ${song.title}',
        icon: const Icon(Icons.more_vert_rounded),
        onPressed: () => showSongOptions(context, song),
      ),
    );
  }
}
