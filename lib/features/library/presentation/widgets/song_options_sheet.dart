import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/player/presentation/screens/sleep_timer_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/metadata_editor_screen.dart';
import 'package:sonaplay/features/library/presentation/screens/playlists_tab.dart';
import 'package:sonaplay/features/library/presentation/screens/ringtone_trimmer_screen.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

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
    // Outlives this sheet, unlike ref: the follow-up flows run after it closes
    final container = ProviderScope.containerOf(context, listen: false);
    final handler = ref.read(audioHandlerProvider);
    final sleepEnds = ref.watch(sleepTimerProvider);
    final songs = [song];

    void close() => Navigator.pop(context);

    Widget item(
      AppIconData icon,
      String label,
      VoidCallback onTap, {
      String? detail,
    }) => ListTile(
      leading: AppIcon(icon),
      title: Text(label),
      subtitle: detail == null ? null : Text(detail),
      onTap: onTap,
    );

    void open(Widget screen) =>
        Navigator.push(host, MaterialPageRoute<void>(builder: (_) => screen));

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
            item(AppIcons.playNext, 'Reproducir a continuación', () {
              close();
              playSongsNext(host, container, songs);
            }),
            item(AppIcons.playlistAdd, 'Agregar a playlist', () {
              close();
              addSongsToPlaylist(host, container, songs);
            }),
            item(AppIcons.share, 'Compartir', () {
              close();
              shareSongs(songs);
            }),
            item(AppIcons.speed, 'Velocidad', () {
              close();
              _pickSpeed(host, container);
            }, detail: '${handler.audioPlayer.speed}x'),
            item(
              AppIcons.sleep,
              'Temporizador para dormir',
              () {
                close();
                pickSleepTimer(host);
              },
              detail: sleepEnds == null
                  ? null
                  : 'Pausa a las ${TimeOfDay.fromDateTime(sleepEnds).format(context)}',
            ),
            item(AppIcons.ringtone, 'Usar como tono de llamada', () {
              close();
              open(RingtoneTrimmerScreen(song: song));
            }),
            item(AppIcons.edit, 'Editar información', () {
              close();
              open(MetadataEditorScreen(song: song));
            }),
            item(AppIcons.hide, 'Ocultar', () {
              close();
              hideSongs(host, songs);
            }),
            item(AppIcons.delete, 'Eliminar', () {
              close();
              trashSongs(host, songs);
            }),
          ],
        ),
      ),
    );
  }
}

// Actions shared by the options sheet (one song) and multi-select (many)

String _count(List<Song> songs, String one, String many) =>
    songs.length == 1 ? one : '${songs.length} $many';

void _notify(BuildContext context, String text, {VoidCallback? undo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        // Snackbars with an action stay until dismissed by default
        persist: false,
        action: undo == null
            ? null
            : SnackBarAction(label: 'Deshacer', onPressed: undo),
      ),
    );
}

Future<void> playSongsNext(
  BuildContext context,
  ProviderContainer ref,
  List<Song> songs,
) async {
  final handler = ref.read(audioHandlerProvider);
  // Each one goes right after the current song, so insert them backwards
  for (final song in songs.reversed) {
    await handler.playNext(song);
  }
  if (context.mounted) {
    _notify(
      context,
      _count(
        songs,
        'Sonará a continuación',
        'canciones sonarán a continuación',
      ),
    );
  }
}

Future<void> shareSongs(List<Song> songs) => SharePlus.instance.share(
  ShareParams(
    files: [for (final s in songs) XFile(s.filePath)],
    title: songs.length == 1 ? songs.first.title : null,
  ),
);

Future<void> hideSongs(BuildContext context, List<Song> songs) async {
  final hidden = HiddenSongsLocalDataSource();
  for (final s in songs) {
    await hidden.hideSong(s.id);
  }
  if (!context.mounted) return;
  _notify(
    context,
    _count(songs, 'Canción ocultada', 'canciones ocultadas'),
    undo: () async {
      for (final s in songs) {
        await hidden.unhideSong(s.id);
      }
    },
  );
}

/// Moves songs to "Eliminado recientemente"; asks first when there are several
/// Returns false if the user backed out
Future<bool> trashSongs(BuildContext context, List<Song> songs) async {
  if (songs.length > 1) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar ${songs.length} canciones?'),
        content: const Text(
          'Irán a Eliminado recientemente, en Ajustes, donde puedes '
          'restaurarlas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }
  final trash = DeletedSongsLocalDataSource();
  for (final s in songs) {
    await trash.softDeleteSong(s.id);
  }
  if (!context.mounted) return true;
  _notify(
    context,
    songs.length == 1
        ? 'Movida a Eliminado recientemente'
        : '${songs.length} canciones movidas a Eliminado recientemente',
    undo: () => trash.forget(songs.map((s) => s.id)),
  );
  return true;
}

/// Returns false if no playlist was picked
Future<bool> addSongsToPlaylist(
  BuildContext context,
  ProviderContainer ref,
  List<Song> songs,
) async {
  // Read once from storage: an unlistened StreamProvider is paused in Riverpod 3,
  // so awaiting its future hangs until the Playlists tab is opened
  final playlists = await ref
      .read(playlistsDataSourceProvider)
      .getAllPlaylists();
  if (!context.mounted) return false;
  final target = await showModalBottomSheet<Playlist?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const CircleAvatar(child: AppIcon(AppIcons.add)),
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
              leading: const AppIcon(AppIcons.queue),
              title: Text(p.name),
              onTap: () => Navigator.pop(sheetContext, p),
            ),
        ],
      ),
    ),
  );
  if (target == null) return false;
  final dataSource = ref.read(playlistsDataSourceProvider);
  var added = 0;
  for (final s in songs) {
    if (await dataSource.addSongToPlaylist(target.id, s.id)) added++;
  }
  if (!context.mounted) return true;
  _notify(
    context,
    added == 0
        ? songs.length == 1
              ? 'Ya estaba en ${target.name}'
              : 'Ya estaban en ${target.name}'
        : added == 1
        ? '1 canción agregada a ${target.name}'
        : '$added canciones agregadas a ${target.name}',
  );
  return true;
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
