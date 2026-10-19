import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/media_store_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/playlists_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/songs_persistence_datasource.dart';
import 'package:sonaplay/features/library/data/models/song_model.dart';
import 'package:sonaplay/features/library/data/services/trash_purger.dart';
import 'package:sonaplay/features/library/data/models/favorite_model.dart';
import 'package:sonaplay/features/library/data/models/hidden_songs_model.dart';
import 'package:sonaplay/features/library/data/models/playlist_model.dart';
import 'package:sonaplay/features/library/data/repositories/favorites_repository_impl.dart';
import 'package:sonaplay/features/library/data/repositories/hidden_songs_repository_impl.dart';
import 'package:sonaplay/features/library/data/repositories/playlists_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/playlist.dart';

/// Simulates the system dialog: only [allowed] IDs get deleted
class _FakeMediaStore extends MediaStoreDataSource {
  final Set<String> allowed;
  _FakeMediaStore({required this.allowed});

  @override
  Future<List<String>> deleteSongs(List<String> songIds) async =>
      songIds.where(allowed.contains).toList();
}

SongModel _song(String id) => SongModel(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  filePath: '/music/$id.mp3',
);

void main() {
  late Directory dir;

  setUpAll(() {
    Hive.registerAdapter(FavoriteModelAdapter());
    Hive.registerAdapter(PlaylistModelAdapter());
    Hive.registerAdapter(HiddenSongsModelAdapter());
    Hive.registerAdapter(SongModelAdapter());
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

  test('TrashPurger cleans up only what the system deleted', () async {
    final trash = DeletedSongsLocalDataSource();
    final favorites = FavoritesLocalDataSource();
    final hidden = HiddenSongsLocalDataSource();
    final playlists = PlaylistsLocalDataSource();
    final cache = SongsPersistenceDataSource();
    await cache.saveSongs([_song('1'), _song('2')]);
    await trash.softDeleteSong('1');
    await trash.softDeleteSong('2');
    await favorites.addFavorite('1');
    await hidden.hideSong('1');
    await playlists.createPlaylist(
      Playlist(
        id: 'p',
        name: 'Mix',
        songIds: const ['1', '2'],
        createdAt: DateTime(2026),
      ),
    );

    final purger = TrashPurger(
      mediaStore: _FakeMediaStore(allowed: {'1'}),
      trash: trash,
      favorites: favorites,
      hidden: hidden,
      playlists: playlists,
      cache: cache,
      ensureWriteAccess: () async {},
    );

    expect(await purger.purge(['1', '2']), ['1']);
    expect(await trash.getDeletedSongIds(), ['2']);
    expect(await favorites.isFavorite('1'), isFalse);
    expect(await hidden.isSongHidden('1'), isFalse);
    expect((await playlists.getPlaylist('p'))!.songIds, ['2']);
    expect((await cache.getCachedSongs()).map((s) => s.id), ['2']);
  });

  test('PlaylistsRepositoryImpl rejects duplicate songs', () async {
    final repo = PlaylistsRepositoryImpl(PlaylistsLocalDataSource());
    await repo.createPlaylist(
      Playlist(
        id: 'p',
        name: 'Mix',
        songIds: const [],
        createdAt: DateTime(2026),
      ),
    );

    expect(await repo.addSongToPlaylist('p', '1'), isTrue);
    expect(await repo.addSongToPlaylist('p', '1'), isFalse);
    expect((await repo.getPlaylist('p'))!.songIds, ['1']);
  });
}
