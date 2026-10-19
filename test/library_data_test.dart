import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/data/models/favorite_model.dart';
import 'package:sonaplay/features/library/data/models/hidden_songs_model.dart';
import 'package:sonaplay/features/library/data/models/playlist_model.dart';
import 'package:sonaplay/features/library/data/repositories/favorites_repository_impl.dart';
import 'package:sonaplay/features/library/data/repositories/hidden_songs_repository_impl.dart';
import 'package:sonaplay/features/library/data/repositories/playlists_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    Hive.registerAdapter(FavoriteModelAdapter());
    Hive.registerAdapter(PlaylistModelAdapter());
    Hive.registerAdapter(HiddenSongsModelAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sonaplay_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  group('DeletedSongsLocalDataSource', () {
    test('soft delete is idempotent and restore removes', () async {
      final ds = DeletedSongsLocalDataSource();
      await ds.softDeleteSong('7');
      await ds.softDeleteSong('7');
      expect(await ds.getDeletedSongIds(), ['7']);

      await ds.restoreSong('7');
      expect(await ds.getDeletedSongIds(), isEmpty);
    });

    test('watch emits on every change', () async {
      final ds = DeletedSongsLocalDataSource();
      final emitted = <List<String>>[];
      final sub = ds.watchDeletedSongs().listen(emitted.add);
      while (emitted.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }

      await ds.softDeleteSong('a');
      await ds.restoreSong('a');
      await pumpEventQueue();
      await sub.cancel();

      expect(emitted, [
        <String>[],
        ['a'],
        <String>[],
      ]);
    });
  });

  test('FavoritesRepositoryImpl toggles on and off', () async {
    final repo = FavoritesRepositoryImpl(FavoritesLocalDataSource());
    await repo.toggleFavorite('1');
    expect(await repo.isFavorite('1'), isTrue);
    await repo.toggleFavorite('1');
    expect(await repo.isFavorite('1'), isFalse);
  });

  test('HiddenSongsRepositoryImpl hides and unhides', () async {
    final repo = HiddenSongsRepositoryImpl(HiddenSongsLocalDataSource());
    await repo.hideSong('1');
    await repo.hideSong('1');
    expect(await repo.getHiddenSongIds(), ['1']);
    await repo.unhideSong('1');
    expect(await repo.isSongHidden('1'), isFalse);
  });

  test('PlaylistsRepositoryImpl rejects duplicate songs', () async {
    final repo = PlaylistsRepositoryImpl(PlaylistsLocalDataSource());
    await repo.createPlaylist(
      Playlist(id: 'p', name: 'Mix', songIds: const [], createdAt: DateTime(2026)),
    );

    expect(await repo.addSongToPlaylist('p', '1'), isTrue);
    expect(await repo.addSongToPlaylist('p', '1'), isFalse);
    expect((await repo.getPlaylist('p'))!.songIds, ['1']);
  });
}
