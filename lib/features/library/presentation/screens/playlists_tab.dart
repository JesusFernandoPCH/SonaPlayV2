import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/presentation/screens/collection_screen.dart';
import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/data/repositories/playlists_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/usecases/create_playlist.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/playlist_cover.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    return GridView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      children: [
        Entrance(
          child: _NewPlaylistCard(
            onTap: () => createPlaylistFlow(
              context,
              ref.read(playlistsDataSourceProvider),
            ),
          ),
        ),
        for (final (i, playlist) in playlists.indexed)
          Entrance(
            key: ValueKey(playlist.id),
            delay: staggerDelay(i + 1),
            child: _PlaylistCard(playlist: playlist),
          ),
      ],
    );
  }
}

/// Dashed tile that starts a new playlist
class _NewPlaylistCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewPlaylistCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AppIcon(AppIcons.add, size: 40, color: scheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nueva playlist',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a name and creates the playlist; returns it (null if cancelled)
Future<Playlist?> createPlaylistFlow(
  BuildContext context,
  PlaylistsLocalDataSource dataSource,
) async {
  final name = await _askName(
    context,
    title: 'Nueva playlist',
    action: 'Crear',
  );
  if (name == null) return null;
  return CreatePlaylist(PlaylistsRepositoryImpl(dataSource))(name);
}

class _PlaylistCard extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  Future<void> _menu(
    BuildContext context,
    PlaylistsLocalDataSource store,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.edit),
              title: const Text('Renombrar'),
              onTap: () => Navigator.pop(sheet, 'rename'),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.delete),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      final name = await _askName(
        context,
        title: 'Renombrar playlist',
        action: 'Guardar',
        initial: playlist.name,
      );
      if (name != null) {
        await store.updatePlaylist(
          playlist.copyWith(name: name, updatedAt: DateTime.now()),
        );
      }
    } else if (action == 'delete' &&
        await _confirmDelete(context, playlist.name)) {
      await store.deletePlaylist(playlist.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(playlistSongsProvider(playlist.id));
    final store = ref.read(playlistsDataSourceProvider);
    final theme = Theme.of(context);
    return Pressable(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
          ),
        ),
        onLongPress: () => _menu(context, store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, box) =>
                    PlaylistCover(songs: songs, size: box.maxWidth),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        songs.length == 1
                            ? '1 canción'
                            : '${songs.length} canciones',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: 'Opciones de ${playlist.name}',
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: const AppIcon(AppIcons.more),
                    onPressed: () => _menu(context, store),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref
        .watch(playlistsProvider)
        .value
        ?.where((p) => p.id == playlistId)
        .firstOrNull;
    return CollectionScreen(
      kind: 'Playlist',
      title: playlist?.name ?? 'Playlist',
      songs: AsyncData(ref.watch(playlistSongsProvider(playlistId))),
      emptyText: 'Esta playlist está vacía. Agrega canciones desde su menú de opciones.',
    );
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, action: action, initial: initial),
);

/// Owns its controller: disposing it when showDialog's future completes
/// is too early (the field is still on screen during the exit animation)
class _NameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  const _NameDialog({
    required this.title,
    required this.action,
    required this.initial,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar playlist?'),
        content: Text('Se eliminará "$name". Las canciones no se borran.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;
