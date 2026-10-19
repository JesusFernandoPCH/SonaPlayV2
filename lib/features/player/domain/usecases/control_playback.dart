import 'package:sonaplay/features/player/domain/entities/player_state.dart';
import 'package:sonaplay/features/player/domain/repositories/audio_repository.dart';

/// Use case for playback controls
class ControlPlayback {
  final AudioRepository repository;

  ControlPlayback(this.repository);

  Future<void> pause() => repository.pause();

  Future<void> resume() => repository.resume();

  Future<void> stop() => repository.stop();

  Future<void> seek(Duration position) => repository.seek(position);

  Future<void> skipToNext() => repository.skipToNext();

  Future<void> skipToPrevious() => repository.skipToPrevious();

  Future<void> setRepeatMode(RepeatMode mode) => repository.setRepeatMode(mode);

  Future<void> toggleShuffle() => repository.toggleShuffle();
}
