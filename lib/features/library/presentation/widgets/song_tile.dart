import 'package:flutter/material.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';

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
      trailing: isCurrent ? const Icon(Icons.graphic_eq_rounded) : null,
    );
  }
}
