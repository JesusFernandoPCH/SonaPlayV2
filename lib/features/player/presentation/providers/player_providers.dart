import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
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

/// Embedded artwork thumbnail per song ID (null when the song has none)
final artworkProvider = FutureProvider.family<Uint8List?, String>((ref, id) {
  return ref.watch(mediaStoreProvider).artwork(id, size: 300);
});

/// App accent: the dominant color of the current song's artwork
final accentColorProvider = FutureProvider<Color>((ref) async {
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
