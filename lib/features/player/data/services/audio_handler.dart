import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/features/library/data/datasources/favorites_local_datasource.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/data/datasources/audio_player_datasource.dart';
import 'package:sonaplay/features/player/data/services/notification_artwork_service.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';

/// AudioHandler for managing audio playback as a foreground service
/// This service survives app removal from Recents and manages media notification
class SonaPlayAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayerDataSource audioPlayer; // Public for provider access
  final NotificationArtworkService _artworkService =
      NotificationArtworkService();

  final FavoritesLocalDataSource _favorites = FavoritesLocalDataSource();

  // Stream subscriptions
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Song?>? _currentSongSubscription;
  StreamSubscription<Set<String>>? _favoritesSubscription;

  /// Kept to redraw the notification buttons when only the favorites change
  PlayerState _lastState = const PlayerState();
  Set<String> _favoriteIds = {};

  /// Song already counted as played this time around (by song ID)
  String? _countedId;

  // Multi-tap detection for wired headphones
  Timer? _clickTimer;
  int _clickCount = 0;

  SonaPlayAudioHandler(this.audioPlayer) {
    _init();
  }

  /// Initialize listeners and set initial state
  void _init() {
    // Listen to player state changes
    _playerStateSubscription = audioPlayer.playerStateStream.listen((state) {
      _updatePlaybackState(state);
    });

    // Listen to current song changes
    _currentSongSubscription = audioPlayer.currentSongStream.listen((song) {
      if (song != null) {
        _countedId = null;
        _updateMediaItem(song);
        _updatePlaybackState(_lastState);
      }
    });

    _favoritesSubscription = _favorites.watchFavoriteIds().listen((ids) {
      _favoriteIds = ids;
      _updatePlaybackState(_lastState);
    });

    // Set initial playback state
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
      ),
    );
  }

  /// Update playback state based on player state
  void _updatePlaybackState(PlayerState state) {
    _lastState = state;
    final songId = audioPlayer.getCurrentSong()?.id;
    _countPlay(songId, state);
    final isFavorite = songId != null && _favoriteIds.contains(songId);
    playbackState.add(
      playbackState.value.copyWith(
        playing: state.isPlaying,
        // Android 13+ shows previous, play and next, plus the first two custom
        // buttons; older versions show all of them in the expanded view
        controls: [
          MediaControl.skipToPrevious,
          state.isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: isFavorite
                ? 'drawable/ic_favorite'
                : 'drawable/ic_favorite_border',
            label: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
            name: 'favorite',
          ),
          MediaControl.custom(
            androidIcon: state.isShuffled
                ? 'drawable/ic_shuffle_on'
                : 'drawable/ic_shuffle_off',
            label: state.isShuffled
                ? 'Aleatorio activado'
                : 'Aleatorio desactivado',
            name: 'toggleShuffle',
          ),
          MediaControl.custom(
            androidIcon: switch (state.repeatMode) {
              RepeatMode.all => 'drawable/ic_repeat_all',
              RepeatMode.one => 'drawable/ic_repeat_one',
              RepeatMode.off => 'drawable/ic_repeat_off',
            },
            label: switch (state.repeatMode) {
              RepeatMode.all => 'Repetir todas',
              RepeatMode.one => 'Repetir una',
              RepeatMode.off => 'Repetir desactivado',
            },
            name: 'cycleRepeat',
          ),
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.ready,
        updatePosition: state.position,
      ),
    );
  }

  /// A song counts as played after 30 s, or half of it if shorter.
  /// ponytail: repeat-one loops count once, reset on position if that matters
  void _countPlay(String? songId, PlayerState state) {
    if (songId == null || songId == _countedId) return;
    final half = state.duration ~/ 2;
    final threshold = half > Duration.zero && half < const Duration(seconds: 30)
        ? half
        : const Duration(seconds: 30);
    if (state.position < threshold) return;
    _countedId = songId;
    final plays = Hive.box('play_counts');
    plays.put(songId, (plays.get(songId, defaultValue: 0) as int) + 1);
  }

  /// Update media item (notification metadata)
  Future<void> _updateMediaItem(Song song) async {
    // 1. Initial update without artwork (fast)
    final baseMediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration != null
          ? Duration(milliseconds: song.duration!)
          : null,
    );
    mediaItem.add(baseMediaItem);

    // 2. Secondary update with artwork (async)
    // We fetch the URI (which might involve caching or content URIs)
    final artUri = await _artworkService.getArtworkUri(song);

    // Only update if the song is still the same one being played
    if (artUri != null && mediaItem.value?.id == song.id) {
      mediaItem.add(baseMediaItem.copyWith(artUri: artUri));
    }
  }

  // ========== Media Controls ==========

  @override
  Future<void> play() async {
    await audioPlayer.resume();
  }

  @override
  Future<void> pause() async {
    await audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await audioPlayer.stop();

    // Update state to stopped
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );

    // This kills the foreground service and removes notification
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    await audioPlayer.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await audioPlayer.skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  // ========== Media Button Handling ==========

  /// Override click to implement multi-tap detection for wired headphones
  ///
  /// Wired headphones with single button send multiple MEDIA_PLAY_PAUSE events.
  /// This method implements a debounced multi-tap detector:
  /// - 1 tap: Play/Pause
  /// - 2 taps: Skip Next
  /// - 3 taps: Skip Previous
  ///
  /// Bluetooth headphones send dedicated Next/Prev events which bypass this logic.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.media) {
      // Multi-tap detection for wired headphones
      _clickCount++;
      _clickTimer?.cancel();

      _clickTimer = Timer(const Duration(milliseconds: 500), () async {
        if (_clickCount == 1) {
          // Single tap: toggle play/pause
          if (playbackState.value.playing) {
            await pause();
          } else {
            await play();
          }
        } else if (_clickCount == 2) {
          // Double tap: skip next
          await skipToNext();
        } else if (_clickCount >= 3) {
          // Triple tap (or more): skip previous
          await skipToPrevious();
        }
        _clickCount = 0;
      });
    } else {
      // Bluetooth or dedicated buttons: use default behavior
      await super.click(button);
    }
  }

  // ========== Custom Actions ==========

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'toggleShuffle':
        await audioPlayer.toggleShuffle();
        break;
      case 'cycleRepeat':
        // Same order as the player screen's repeat button
        await audioPlayer.setRepeatMode(switch (_lastState.repeatMode) {
          RepeatMode.all => RepeatMode.one,
          RepeatMode.one => RepeatMode.off,
          RepeatMode.off => RepeatMode.all,
        });
        break;
      case 'favorite':
        final songId = audioPlayer.getCurrentSong()?.id;
        if (songId == null) break;
        _favoriteIds.contains(songId)
            ? await _favorites.removeFavorite(songId)
            : await _favorites.addFavorite(songId);
        break;
    }
  }

  /// Play Next - move or insert song at currentIndex + 1 (FASE 7.2)
  Future<void> playNext(Song song) async {
    final currentIndex = audioPlayer.currentIndex;

    if (currentIndex == null || audioPlayer.currentPlaylist.isEmpty) {
      // No song playing, just play this song
      await audioPlayer.setPlaylist([song], 0);
      return;
    }

    // 1. Check if it's the current song
    final currentSong = audioPlayer.getCurrentSong();
    if (currentSong?.id == song.id) {
      // Already playing, do nothing
      return;
    }

    final currentQueue = List<Song>.from(audioPlayer.currentPlaylist);
    final targetIndex = currentIndex + 1;

    // 2. Check if the song is already in the queue
    final existingIndex = currentQueue.indexWhere((s) => s.id == song.id);

    if (existingIndex != -1) {
      // Song exists, move it to target position
      await audioPlayer.reorderQueue(existingIndex, targetIndex);
    } else {
      // Song doesn't exist, insert it
      if (targetIndex <= currentQueue.length) {
        currentQueue.insert(targetIndex, song);
      } else {
        currentQueue.add(song);
      }
      // Update queue without interrupting playback
      await audioPlayer.updateQueue(currentQueue);
    }
  }

  /// Play a specific song with playlist
  Future<void> playSong(Song song, List<Song> playlist, int index) async {
    await audioPlayer.setPlaylist(playlist, index);
  }

  /// Skip to index in current queue (FASE 7.2 optimization)
  Future<void> skipToIndex(int index) async {
    await audioPlayer.skipToIndex(index);
  }

  /// Dispose resources
  @override
  Future<void> onTaskRemoved() async {
    // Don't stop audio when task is removed
    // This allows audio to continue when app is swiped from Recents
    // Audio will only stop when user explicitly stops it
  }

  void dispose() {
    _clickTimer?.cancel();
    _playerStateSubscription?.cancel();
    _currentSongSubscription?.cancel();
    _favoritesSubscription?.cancel();
  }
}
