import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sonaplay/core/appearance/appearance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/metadata_persistence_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/data/services/audio_handler.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/main.dart';

final audioHandlerProvider = Provider<SonaPlayAudioHandler>(
  (ref) => audioHandler,
);

final currentSongProvider = StreamProvider<Song?>((ref) async* {
  final player = ref.watch(audioHandlerProvider).audioPlayer;
  yield player.getCurrentSong();
  yield* player.currentSongStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioHandlerProvider).audioPlayer.playerStateStream;
});

final mediaStoreProvider = Provider((ref) => MediaStoreDataSource());

final metadataProvider = Provider((ref) => MetadataPersistenceDataSource());

/// Artwork picked in the metadata editor, else the embedded one (null: none)
Future<Uint8List?> _artwork(Ref ref, String id, int size) async {
  final custom =
      (await ref.watch(metadataProvider).getOverride(id))?['artworkPath']
          as String?;
  if (custom != null && File(custom).existsSync()) {
    return File(custom).readAsBytes();
  }
  return ref.watch(mediaStoreProvider).artwork(id, size: size);
}

/// Artwork thumbnail per song ID
final artworkProvider = FutureProvider.family<Uint8List?, String>(
  (ref, id) => _artwork(ref, id, 300),
);

/// Sharper artwork for the full-screen player
final largeArtworkProvider = FutureProvider.family<Uint8List?, String>(
  (ref, id) => _artwork(ref, id, 900),
);

/// Sleep timer: when it fires playback pauses; state = when it ends (null: off)
final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, DateTime?>(
  SleepTimerNotifier.new,
);

class SleepTimerNotifier extends Notifier<DateTime?> {
  Timer? _timer;

  @override
  DateTime? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void start(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      ref.read(audioHandlerProvider).audioPlayer.pause();
      state = null;
    });
    state = DateTime.now().add(duration);
  }

  void cancel() {
    _timer?.cancel();
    state = null;
  }
}

/// App accent: the dominant color of the current song's artwork
final accentColorProvider = FutureProvider<Color>((ref) async {
  final appearance = ref.watch(appearanceProvider);
  if (!appearance.accentFromArtwork) return appearance.fixedAccent;
  final song = ref.watch(currentSongProvider).value;
  if (song == null) return kDefaultAccent;
  final bytes = await ref.watch(artworkProvider(song.id).future);
  if (bytes == null) return kDefaultAccent;
  final scheme = await ColorScheme.fromImageProvider(
    provider: MemoryImage(bytes),
    brightness: Brightness.dark,
  );
  return scheme.primary;
});
