import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Rounded square artwork of a song, with a note icon when it has none
class Artwork extends ConsumerWidget {
  final String songId;
  final double size;

  const Artwork({super.key, required this.songId, this.size = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(artworkProvider(songId)).value;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: SizedBox.square(
        dimension: size,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.music_note_rounded,
                  size: size * 0.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
