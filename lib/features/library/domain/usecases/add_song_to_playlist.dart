import 'package:sonaplay/features/library/domain/repositories/playlists_repository.dart';

/// Use case for adding a song to a playlist
class AddSongToPlaylist {
  final PlaylistsRepository _repository;

  AddSongToPlaylist(this._repository);

  Future<bool> call(String playlistId, String songId) async {
    return await _repository.addSongToPlaylist(playlistId, songId);
  }
}
