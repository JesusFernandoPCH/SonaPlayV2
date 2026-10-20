import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonaplay/core/legal/legal.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/services/trash_purger.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';
import 'package:sonaplay/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:sonaplay/features/settings/presentation/appearance_screen.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _settings = SettingsLocalDataSource();

  Future<void> _pickMinDuration() async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Ocultar audios más cortos que'),
        children: [
          RadioGroup<int>(
            groupValue: _settings.minDuration,
            onChanged: (v) => Navigator.pop(dialogContext, v),
            child: Column(
              children: [
                for (final s in const [0, 10, 30, 60, 120])
                  RadioListTile<int>(
                    value: s,
                    title: Text(s == 0 ? 'Mostrar todo' : '$s segundos'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (seconds == null) return;
    await _settings.setMinDuration(seconds);
    setState(() {});
    // The filter is applied while scanning, so scan again
    ref.invalidate(songsProvider);
  }

  Box get _box => Hive.box('settings_box');

  /// The name the daily card greets with; empty removes it
  Future<void> _editName() async {
    final controller = TextEditingController(
      text: _box.get('user_name') as String?,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Cómo quieres que te salude',
          ),
          onSubmitted: (v) => Navigator.pop(dialog, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    name.trim().isEmpty
        ? await _box.delete('user_name')
        : await _box.put('user_name', name.trim());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userName = _box.get('user_name') as String?;
    final hidden = ref.watch(hiddenIdsProvider).value?.length ?? 0;
    final trashed = ref.watch(trashIdsProvider).value?.length ?? 0;
    final minDuration = _settings.minDuration;
    void open(Widget screen) => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          header('Personalización'),
          ListTile(
            leading: const AppIcon(AppIcons.user),
            title: const Text('Tu nombre'),
            subtitle: Text(userName ?? 'Sin nombre'),
            onTap: _editName,
          ),
          ListTile(
            leading: const AppIcon(AppIcons.palette),
            title: const Text('Apariencia'),
            subtitle: const Text('Fondo, difuminado y color de acento'),
            trailing: const AppIcon(AppIcons.chevronRight),
            onTap: () => open(const AppearanceScreen()),
          ),
          header('Biblioteca'),
          ListTile(
            leading: const AppIcon(AppIcons.hide),
            title: const Text('Archivos ocultos'),
            subtitle: Text(hidden == 1 ? '1 canción' : '$hidden canciones'),
            trailing: const AppIcon(AppIcons.chevronRight),
            onTap: () => open(const _HiddenSongsScreen()),
          ),
          ListTile(
            leading: const AppIcon(AppIcons.delete),
            title: const Text('Eliminado recientemente'),
            subtitle: Text(trashed == 1 ? '1 canción' : '$trashed canciones'),
            trailing: const AppIcon(AppIcons.chevronRight),
            onTap: () => open(const _TrashScreen()),
          ),
          ListTile(
            leading: const AppIcon(AppIcons.timer),
            title: const Text('Duración mínima'),
            subtitle: Text(
              minDuration == 0
                  ? 'Se muestran todos los audios'
                  : 'Se ocultan audios de menos de $minDuration segundos',
            ),
            onTap: _pickMinDuration,
          ),
          header('Acerca de'),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => ListTile(
              leading: const AppIcon(AppIcons.info),
              title: const Text('SonaPlay'),
              subtitle: Text(
                snap.hasData ? 'Versión ${snap.data!.version}' : '',
              ),
            ),
          ),
          ListTile(
            leading: const AppIcon(AppIcons.legal),
            title: const Text('Términos y Condiciones'),
            trailing: const AppIcon(AppIcons.chevronRight),
            onTap: () => openLegal(context, privacy: false),
          ),
          ListTile(
            leading: const AppIcon(AppIcons.privacy),
            title: const Text('Aviso de Privacidad'),
            trailing: const AppIcon(AppIcons.chevronRight),
            onTap: () => openLegal(context, privacy: true),
          ),
        ],
      ),
    );
  }
}

/// Songs whose IDs are in [ids], taken from the full (unfiltered) library
List<Song> _songsWithIds(WidgetRef ref, List<String>? ids) {
  final wanted = {...?ids};
  return [
    for (final s in ref.watch(songsProvider).value ?? const <Song>[])
      if (wanted.contains(s.id)) s,
  ];
}

class _HiddenSongsScreen extends ConsumerWidget {
  const _HiddenSongsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = _songsWithIds(ref, ref.watch(hiddenIdsProvider).value);
    return Scaffold(
      appBar: AppBar(title: const Text('Archivos ocultos')),
      body: songs.isEmpty
          ? const CenteredMessage(
              'No hay canciones ocultas',
              icon: AppIcons.show,
            )
          : ListView(
              children: [
                for (final song in songs)
                  _SongRow(
                    song: song,
                    action: TextButton(
                      onPressed: () =>
                          HiddenSongsLocalDataSource().unhideSong(song.id),
                      child: const Text('Mostrar'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TrashScreen extends ConsumerWidget {
  const _TrashScreen();

  Future<void> _purge(
    BuildContext context,
    List<String> ids, {
    required String question,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(question),
        content: const Text(
          'Los archivos se borran del teléfono y no se pueden recuperar.',
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
    if (confirmed != true || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final deleted = await TrashPurger().purge(ids);
    // The files are gone: rescan so they don't come back once out of the trash,
    // and drop them from the queue (moving on if one was playing)
    container.invalidate(songsProvider);
    await container
        .read(audioHandlerProvider)
        .audioPlayer
        .removeSongs(deleted.toSet());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted.isEmpty
              ? 'No se eliminó ningún archivo'
              : deleted.length == 1
              ? '1 archivo eliminado del teléfono'
              : '${deleted.length} archivos eliminados del teléfono',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(trashIdsProvider).value ?? const <String>[];
    final songs = _songsWithIds(ref, ids);
    final trash = DeletedSongsLocalDataSource();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eliminado recientemente'),
        actions: [
          if (ids.isNotEmpty)
            TextButton(
              onPressed: () =>
                  _purge(context, ids, question: '¿Vaciar la papelera?'),
              child: const Text('Vaciar'),
            ),
        ],
      ),
      body: songs.isEmpty
          ? const CenteredMessage(
              'La papelera está vacía',
              icon: AppIcons.delete,
            )
          : ListView(
              children: [
                for (final song in songs)
                  _SongRow(
                    song: song,
                    action: PopupMenuButton<String>(
                      tooltip: 'Opciones de ${song.title}',
                      onSelected: (action) => action == 'restore'
                          ? trash.restoreSong(song.id)
                          : _purge(context, [
                              song.id,
                            ], question: '¿Eliminar "${song.title}"?'),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'restore',
                          child: Text('Restaurar'),
                        ),
                        PopupMenuItem(
                          value: 'purge',
                          child: Text('Eliminar definitivamente'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final Song song;
  final Widget action;
  const _SongRow({required this.song, required this.action});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Artwork(songId: song.id),
    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    // The file name tells apart copies of the same song
    subtitle: Text(
      '${song.artist}\n${song.filePath.split('/').last}',
      // Long names wrap: the end is often what differs (e.g. "_1.mp3")
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    isThreeLine: true,
    trailing: action,
  );
}
