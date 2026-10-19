import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';

/// Abstract repository for audio playback operations
abstract class AudioRepository {
  /// Play a specific song
  Future<void> play(Song song);

  /// Pause playback
  Future<void> pause();

  /// Resume playback
  Future<void> resume();

  /// Stop playback
  Future<void> stop();

  /// Seek to a specific position
  Future<void> seek(Duration position);

  /// Set playlist and start playing from specific index
  Future<void> setPlaylist(List<Song> songs, int startIndex);

  /// Skip to next song
  Future<void> skipToNext();

  /// Skip to previous song
  Future<void> skipToPrevious();

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode);

  /// Toggle shuffle
  Future<void> toggleShuffle();

  /// Get current song
  Song? getCurrentSong();

  /// Get current playlist
  List<Song> getPlaylist();

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream;

  /// Stream of current song changes
  Stream<Song?> get currentSongStream;
}
