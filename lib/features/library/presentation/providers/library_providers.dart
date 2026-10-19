import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/data/datasources/deleted_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/hidden_songs_local_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/local_music_datasource.dart';
import 'package:sonaplay/features/library/data/datasources/metadata_persistence_datasource.dart';
import 'package:sonaplay/features/library/data/repositories/library_repository_impl.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';

/// All device songs: cached list first, then the fresh MediaStore scan
final songsProvider = StreamProvider<List<Song>>((ref) {
  return LibraryRepositoryImpl(
    LocalMusicDataSource(),
    MetadataPersistenceDataSource(),
  ).getAllSongs();
});

final trashIdsProvider = StreamProvider<List<String>>((ref) {
  return DeletedSongsLocalDataSource().watchDeletedSongs();
});

final hiddenIdsProvider = StreamProvider<List<String>>((ref) {
  return HiddenSongsLocalDataSource().watchHiddenSongIds();
});

/// Library songs without the hidden ones and the ones in the trash
final visibleSongsProvider = Provider<AsyncValue<List<Song>>>((ref) {
  final excluded = {
    ...?ref.watch(hiddenIdsProvider).value,
    ...?ref.watch(trashIdsProvider).value,
  };
  return ref
      .watch(songsProvider)
      .whenData(
        (songs) => songs.where((s) => !excluded.contains(s.id)).toList(),
      );
});
