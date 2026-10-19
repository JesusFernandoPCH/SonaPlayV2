import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Edits title, artist, album and artwork. Changes stay inside the app;
/// the audio file is never modified.
class MetadataEditorScreen extends ConsumerStatefulWidget {
  final Song song;
  const MetadataEditorScreen({super.key, required this.song});

  @override
  ConsumerState<MetadataEditorScreen> createState() =>
      _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends ConsumerState<MetadataEditorScreen> {
  late final _title = TextEditingController(text: widget.song.title);
  late final _artist = TextEditingController(text: widget.song.artist);
  late final _album = TextEditingController(text: widget.song.album ?? '');

  /// Picked image, still in the picker's cache until saved
  String? _pickedArtwork;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  Future<void> _pickArtwork() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (image != null) setState(() => _pickedArtwork = image.path);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final id = widget.song.id;

    String? artworkPath;
    if (_pickedArtwork case final picked?) {
      // The picker's file lives in cache; keep a copy the app owns
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/artwork',
      );
      await dir.create(recursive: true);
      artworkPath = (await File(picked).copy(
        '${dir.path}/${id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      )).path;
    }

    await ref
        .read(metadataProvider)
        .saveOverride(
          songId: id,
          title: title,
          artist: _artist.text.trim(),
          album: _album.text.trim(),
          artworkPath: artworkPath,
        );
    ref
      ..invalidate(songsProvider)
      ..invalidate(artworkProvider(id))
      ..invalidate(largeArtworkProvider(id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Información actualizada en SonaPlay')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar información'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: _pickedArtwork != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(size * 0.16),
                    child: Image.file(
                      File(_pickedArtwork!),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    ),
                  )
                : Artwork(songId: widget.song.id, size: size, large: true),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _pickArtwork,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Cambiar carátula'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _artist,
            decoration: const InputDecoration(labelText: 'Artista'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _album,
            decoration: const InputDecoration(labelText: 'Álbum'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          Text(
            'Los cambios solo se ven en SonaPlay; el archivo de audio no se modifica.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
