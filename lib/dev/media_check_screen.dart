import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sonaplay/core/services/permission_service.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/library/data/services/trash_purger.dart';
import 'package:sonaplay/main.dart';

// ponytail: throwaway harness to verify the MediaStore channel on a device;
// replaced by the UI/UX redesign.
class MediaCheckScreen extends StatefulWidget {
  const MediaCheckScreen({super.key});

  @override
  State<MediaCheckScreen> createState() => _MediaCheckScreenState();
}

class _MediaCheckScreenState extends State<MediaCheckScreen> {
  final _mediaStore = MediaStoreDataSource();
  final _trash = DeletedSongsLocalDataSource();
  final _artwork = <String, Future<Uint8List?>>{};
  List<SongModel>? _songs;
  List<String> _trashIds = [];
  bool _showTrash = false;
  String _status = 'Pidiendo permiso…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!await PermissionService().requestAudioPermission()) {
      setState(() => _status = 'Permiso de audio denegado');
      return;
    }
    final songs = await _mediaStore.querySongs();
    final trashIds = await _trash.getDeletedSongIds();
    setState(() {
      _songs = songs;
      _trashIds = trashIds;
      _status = '${songs.length} canciones · ${trashIds.length} en papelera';
    });
  }

  Future<void> _purge() async {
    final deleted = await TrashPurger().purge(_trashIds);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eliminadas del dispositivo: ${deleted.length}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = (_songs ?? [])
        .where((s) => _trashIds.contains(s.id) == _showTrash)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_showTrash ? 'Papelera' : 'SonaPlay V2 · prueba'),
        actions: [
          IconButton(
            key: const Key('toggle-trash'),
            icon: Icon(_showTrash ? Icons.library_music : Icons.delete_outline),
            onPressed: () => setState(() => _showTrash = !_showTrash),
          ),
          if (_showTrash && _trashIds.isNotEmpty)
            TextButton(
              key: const Key('purge'),
              onPressed: _purge,
              child: const Text('Eliminar definitivamente'),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Text(_status),
        ),
      ),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (context, i) {
          final song = songs[i];
          return ListTile(
            leading: SizedBox.square(
              dimension: 48,
              child: FutureBuilder(
                future: _artwork.putIfAbsent(
                  song.id,
                  () => _mediaStore.artwork(song.id, size: 144),
                ),
                builder: (context, snap) => snap.data != null
                    ? Image.memory(snap.data!, fit: BoxFit.cover)
                    : const Icon(Icons.music_note),
              ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _showTrash
                  ? song.filePath
                  : '${song.artist} · ${song.formattedDuration}',
            ),
            onTap: () => audioHandler.playSong(song, songs, i),
            onLongPress: () async {
              _showTrash
                  ? await _trash.restoreSong(song.id)
                  : await _trash.softDeleteSong(song.id);
              await _load();
            },
          );
        },
      ),
    );
  }
}
