import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/presentation/screens/collection_screen.dart';
import 'package:sonaplay/features/library/domain/entities/folder.dart';
import 'package:sonaplay/features/library/domain/library_query.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class FoldersTab extends ConsumerWidget {
  const FoldersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(foldersProvider)) {
      AsyncData(:final value) when value.isEmpty => const CenteredMessage(
        'No hay carpetas con música',
        icon: AppIcons.folderOff,
      ),
      AsyncData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, i) => _FolderTile(folder: value[i]),
      ),
      AsyncError() => const CenteredMessage('No se pudo leer la música'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _FolderTile extends StatelessWidget {
  final Folder folder;
  const _FolderTile({required this.folder});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Artwork(songId: folder.songs.first.id),
      title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${folder.songCount == 1 ? '1 canción' : '${folder.songCount} canciones'}'
        ' · ${folder.path}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const AppIcon(AppIcons.chevronRight),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              FolderDetailScreen(path: folder.path, name: folder.name),
        ),
      ),
    );
  }
}

class FolderDetailScreen extends ConsumerWidget {
  final String path;
  final String name;
  const FolderDetailScreen({super.key, required this.path, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(sortOptionProvider);
    final songs = ref
        .watch(foldersProvider)
        .whenData(
          (folders) => sortSongs(
            folders.where((f) => f.path == path).firstOrNull?.songs ?? const [],
            sort,
          ),
        );
    return CollectionScreen(
      kind: 'Carpeta',
      title: name,
      songs: songs,
      emptyText: 'Esta carpeta ya no tiene música',
    );
  }
}
