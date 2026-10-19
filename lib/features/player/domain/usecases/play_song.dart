import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/domain/repositories/audio_repository.dart';

/// Use case to play a song
class PlaySong {
  final AudioRepository repository;

  PlaySong(this.repository);

  Future<void> call(Song song, {List<Song>? playlist, int? index}) async {
    if (playlist != null && index != null) {
      await repository.setPlaylist(playlist, index);
    } else {
      await repository.play(song);
    }
  }
}
