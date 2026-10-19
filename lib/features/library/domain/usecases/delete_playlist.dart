import 'package:sonaplay/features/library/domain/repositories/playlists_repository.dart';

/// Use case for deleting a playlist
class DeletePlaylist {
  final PlaylistsRepository _repository;

  DeletePlaylist(this._repository);

  Future<void> call(String playlistId) async {
    await _repository.deletePlaylist(playlistId);
  }
}
