import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/data/repositories/playlists_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/usecases/create_playlist.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/playlist_cover.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';

class PlaylistsTab extends ConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
          title: const Text('Nueva playlist'),
          onTap: () => createPlaylistFlow(context, ref),
        ),
        if (playlists.isEmpty)
          const CenteredMessage(
            'Aún no tienes playlists',
            icon: Icons.queue_music_rounded,
          ),
        for (final playlist in playlists) _PlaylistTile(playlist: playlist),
      ],
    );
  }
}

/// Asks for a name and creates the playlist; returns it (null if cancelled)
Future<Playlist?> createPlaylistFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await _askName(
    context,
    title: 'Nueva playlist',
    action: 'Crear',
  );
  if (name == null) return null;
  final repository = PlaylistsRepositoryImpl(
    ref.read(playlistsDataSourceProvider),
  );
  return CreatePlaylist(repository)(name);
}

class _PlaylistTile extends ConsumerWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(playlistSongsProvider(playlist.id));
    final dataSource = ref.read(playlistsDataSourceProvider);
    return ListTile(
      leading: PlaylistCover(songs: songs),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        songs.length == 1 ? '1 canción' : '${songs.length} canciones',
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones de la playlist',
        onSelected: (action) async {
          if (action == 'rename') {
            final name = await _askName(
              context,
              title: 'Renombrar playlist',
              action: 'Guardar',
              initial: playlist.name,
            );
            if (name != null) {
              await dataSource.updatePlaylist(
                playlist.copyWith(name: name, updatedAt: DateTime.now()),
              );
            }
          } else if (await _confirmDelete(context, playlist.name)) {
            await dataSource.deletePlaylist(playlist.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Renombrar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
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
    return Scaffold(
      appBar: AppBar(title: Text(playlist?.name ?? 'Playlist')),
      body: SongListView(
        songs: AsyncData(ref.watch(playlistSongsProvider(playlistId))),
        emptyText: 'Esta playlist está vacía. Agrega canciones desde su menú de opciones.',
      ),
      bottomNavigationBar: const MiniPlayer(),
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
