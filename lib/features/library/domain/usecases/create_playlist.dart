import 'package:sonaplay/features/library/domain/entities/playlist.dart';
import 'package:sonaplay/features/library/domain/repositories/playlists_repository.dart';
import 'package:uuid/uuid.dart';

/// Use case for creating a new playlist
class CreatePlaylist {
  final PlaylistsRepository _repository;
  final _uuid = const Uuid();

  CreatePlaylist(this._repository);

  Future<Playlist> call(String name) async {
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      songIds: [],
      createdAt: DateTime.now(),
    );
    await _repository.createPlaylist(playlist);
    return playlist;
  }
}
