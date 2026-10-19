import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/metadata_editor_screen.dart';
import 'package:sonaplay/features/library/presentation/screens/playlists_tab.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Bottom sheet with every action for one song
void showSongOptions(BuildContext context, Song song) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _SongOptions(song: song, host: context),
  );
}

class _SongOptions extends ConsumerWidget {
  final Song song;

  /// Screen that opened the sheet: snackbars and follow-up dialogs live there,
  /// since the sheet itself is gone by the time they show
  final BuildContext host;

  const _SongOptions({required this.song, required this.host});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(host);
    // Outlives this sheet, unlike ref: the follow-up flows run after it closes
    final container = ProviderScope.containerOf(context, listen: false);
    final handler = ref.read(audioHandlerProvider);
    final sleepEnds = ref.watch(sleepTimerProvider);

    void close() => Navigator.pop(context);

    void notify(String text, {VoidCallback? undo}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            action: undo == null
                ? null
                : SnackBarAction(label: 'Deshacer', onPressed: undo),
          ),
        );
    }

    Widget item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      String? detail,
    }) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: detail == null ? null : Text(detail),
      onTap: onTap,
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(songId: song.id),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            item(Icons.playlist_play_rounded, 'Reproducir a continuación', () {
              close();
              handler.playNext(song);
              notify('Sonará a continuación');
            }),
            item(Icons.playlist_add_rounded, 'Agregar a playlist', () {
              close();
              _addToPlaylist(host, container, song, notify);
            }),
            item(Icons.share_rounded, 'Compartir', () {
              close();
              SharePlus.instance.share(
                ShareParams(files: [XFile(song.filePath)], title: song.title),
              );
            }),
            item(Icons.speed_rounded, 'Velocidad', () {
              close();
              _pickSpeed(host, container);
            }, detail: '${handler.audioPlayer.speed}x'),
            item(
              Icons.bedtime_rounded,
              'Temporizador para dormir',
              () {
                close();
                _pickSleepTimer(host, container);
              },
              detail: sleepEnds == null
                  ? null
                  : 'Pausa a las ${TimeOfDay.fromDateTime(sleepEnds).format(context)}',
            ),
            item(Icons.edit_rounded, 'Editar información', () {
              close();
              Navigator.push(
                host,
                MaterialPageRoute<void>(
                  builder: (_) => MetadataEditorScreen(song: song),
                ),
              );
            }),
            item(Icons.visibility_off_rounded, 'Ocultar', () async {
              close();
              final hidden = HiddenSongsLocalDataSource();
              await hidden.hideSong(song.id);
              notify(
                'Canción ocultada',
                undo: () => hidden.unhideSong(song.id),
              );
            }),
            item(Icons.delete_outline_rounded, 'Eliminar', () async {
              close();
              final trash = DeletedSongsLocalDataSource();
              await trash.softDeleteSong(song.id);
              notify(
                'Movida a Eliminado recientemente',
                undo: () => trash.restoreSong(song.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

Future<void> _addToPlaylist(
  BuildContext context,
  ProviderContainer ref,
  Song song,
  void Function(String) notify,
) async {
  // Read once from storage: an unlistened StreamProvider is paused in Riverpod 3,
  // so awaiting its future hangs until the Playlists tab is opened
  final playlists = await ref
      .read(playlistsDataSourceProvider)
      .getAllPlaylists();
  if (!context.mounted) return;
  final target = await showModalBottomSheet<Playlist?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
            title: const Text('Nueva playlist'),
            onTap: () async {
              final created = await createPlaylistFlow(
                sheetContext,
                ref.read(playlistsDataSourceProvider),
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext, created);
            },
          ),
          for (final p in playlists)
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(p.name),
              onTap: () => Navigator.pop(sheetContext, p),
            ),
        ],
      ),
    ),
  );
  if (target == null) return;
  final added = await ref
      .read(playlistsDataSourceProvider)
      .addSongToPlaylist(target.id, song.id);
  notify(added ? 'Agregada a ${target.name}' : 'Ya estaba en ${target.name}');
}

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

Future<void> _pickSpeed(BuildContext context, ProviderContainer ref) async {
  final player = ref.read(audioHandlerProvider).audioPlayer;
  final speed = await showDialog<double>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Velocidad de reproducción'),
      children: [
        RadioGroup<double>(
          groupValue: player.speed,
          onChanged: (v) => Navigator.pop(dialogContext, v),
          child: Column(
            children: [
              for (final s in _speeds)
                RadioListTile<double>(
                  value: s,
                  title: Text(s == 1.0 ? 'Normal (1x)' : '${s}x'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (speed != null) await player.setSpeed(speed);
}

const _sleepMinutes = [15, 30, 45, 60, 90];

Future<void> _pickSleepTimer(
  BuildContext context,
  ProviderContainer ref,
) async {
  final timer = ref.read(sleepTimerProvider.notifier);
  final active = ref.read(sleepTimerProvider) != null;
  final minutes = await showDialog<int>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Pausar la música en'),
      children: [
        for (final m in _sleepMinutes)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, m),
            child: Text('$m minutos'),
          ),
        if (active)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 0),
            child: const Text('Desactivar temporizador'),
          ),
      ],
    ),
  );
  if (minutes == null) return;
  minutes == 0 ? timer.cancel() : timer.start(Duration(minutes: minutes));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          minutes == 0
              ? 'Temporizador desactivado'
              : 'La música se pausará en $minutes minutos',
        ),
      ),
    );
  }
}
