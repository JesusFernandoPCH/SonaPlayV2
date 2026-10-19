import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/data/datasources/audio_player_datasource.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/player/domain/repositories/audio_repository.dart';

/// Implementation of AudioRepository
class AudioRepositoryImpl implements AudioRepository {
  final AudioPlayerDataSource dataSource;

  AudioRepositoryImpl(this.dataSource);

  @override
  Future<void> play(Song song) => dataSource.play(song);

  @override
  Future<void> pause() => dataSource.pause();

  @override
  Future<void> resume() => dataSource.resume();

  @override
  Future<void> stop() => dataSource.stop();

  @override
  Future<void> seek(Duration position) => dataSource.seek(position);

  @override
  Future<void> setPlaylist(List<Song> songs, int startIndex) =>
      dataSource.setPlaylist(songs, startIndex);

  @override
  Future<void> skipToNext() => dataSource.skipToNext();

  @override
  Future<void> skipToPrevious() => dataSource.skipToPrevious();

  @override
  Future<void> setRepeatMode(RepeatMode mode) => dataSource.setRepeatMode(mode);

  @override
  Future<void> toggleShuffle() => dataSource.toggleShuffle();

  @override
  Song? getCurrentSong() => dataSource.getCurrentSong();

  @override
  List<Song> getPlaylist() => dataSource.getPlaylist();

  @override
  Stream<PlayerState> get playerStateStream => dataSource.playerStateStream;

  @override
  Stream<Song?> get currentSongStream => dataSource.currentSongStream;
}
