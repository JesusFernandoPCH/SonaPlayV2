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
  static const _fade = Duration(seconds: 15);
  Timer? _timer;
  StreamSubscription<PlayerState>? _songChange;

  /// Length it was set to, for the countdown ring
  Duration total = Duration.zero;

  @override
  DateTime? build() {
    ref.onDispose(_stop);
    return null;
  }

  /// Turns the volume down over the last seconds, then pauses. With
  /// [endOfSong] it pauses when the track changes instead, since a pause right
  /// at the end races the move to the next song.
  void start(Duration duration, {bool endOfSong = false}) {
    _stop();
    total = duration;
    final ends = DateTime.now().add(duration);
    state = ends;
    final player = ref.read(audioHandlerProvider).audioPlayer;
    if (endOfSong) {
      // Once the next song is actually playing (it's announced before it
      // loads, and loading starts it), pause it and rewind
      final songId = player.getCurrentSong()?.id;
      _songChange = player.playerStateStream.listen((playing) {
        if (playing.isPlaying && player.getCurrentSong()?.id != songId) {
          _finish(rewind: true);
        }
      });
    }
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final left = ends.difference(DateTime.now());
      if (left > _fade) return;
      if (left > Duration.zero) {
        player.setVolume(left.inMilliseconds / _fade.inMilliseconds);
      } else if (!endOfSong || left < -const Duration(seconds: 3)) {
        _finish();
      }
    });
  }

  Future<void> _finish({bool rewind = false}) async {
    _stop();
    state = null;
    final player = ref.read(audioHandlerProvider).audioPlayer;
    await player.pause();
    if (rewind) await player.seek(Duration.zero);
    // A track change in flight can start playback again right after
    await Future<void>.delayed(const Duration(seconds: 1));
    if (player.playing) await player.pause();
    await player.setVolume(1);
  }

  void _stop() {
    _timer?.cancel();
    _songChange?.cancel();
    _songChange = null;
  }

  void cancel() {
    _stop();
    state = null;
    ref.read(audioHandlerProvider).audioPlayer.setVolume(1);
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
