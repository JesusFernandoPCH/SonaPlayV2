import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/player/data/datasources/playback_persistence_datasource.dart';
import 'package:sonaplay/features/player/domain/entities/player_state.dart';

/// Datasource for audio playback using just_audio
class AudioPlayerDataSource {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<Song?> _currentSongController =
      StreamController<Song?>.broadcast();

  final PlaybackPersistenceDataSource _persistence;
  List<Song> _originalPlaylist = [];
  List<Song> _shuffledPlaylist = [];
  int _currentIndex = 0;
  late bool _isShuffled;
  late RepeatMode _repeatMode;

  // Get active playlist based on shuffle state
  List<Song> get _activePlaylist =>
      _isShuffled ? _shuffledPlaylist : _originalPlaylist;

  // Public getters for queue state (FASE 7.2)
  bool get isShuffled => _isShuffled;
  List<Song> get currentPlaylist => List.unmodifiable(_activePlaylist);
  int? get currentIndex => _activePlaylist.isEmpty ? null : _currentIndex;

  AudioPlayerDataSource(this._persistence) {
    _isShuffled = _persistence.shuffleMode;
    _repeatMode = _persistence.repeatMode;
    _initAudioSession();
    _setupPlayerListeners();
  }

  /// Initialize audio session for proper audio focus handling
  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  /// Setup listeners for player state changes
  void _setupPlayerListeners() {
    // Listen to playback state changes
    _player.playingStream.listen((isPlaying) {
      _emitState();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      _emitState();
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      _emitState();
    });

    // Listen to player completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ja.ProcessingState.completed) {
        _handleSongCompletion();
      }
    });
  }

  /// Emit current player state
  void _emitState() {
    final state = PlayerState(
      isPlaying: _player.playing,
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      isShuffled: _isShuffled,
      repeatMode: _repeatMode,
    );
    _stateController.add(state);
  }

  /// Handle song completion based on repeat mode
  Future<void> _handleSongCompletion() async {
    if (_repeatMode == RepeatMode.one) {
      // Repeat current song
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      // RepeatMode.all - go to next or loop
      if (_currentIndex < _activePlaylist.length - 1) {
        await skipToNext();
      } else {
        // Loop back to start
        await _playSongAtIndex(0);
      }
    }
  }

  /// Play a specific song
  Future<void> play(Song song) async {
    try {
      // Emit state BEFORE playing for immediate UI feedback
      _currentSongController.add(song);
      _emitState();

      await _player.setFilePath(song.filePath);
      await _player.play();
    } catch (e) {
      throw Exception('Failed to play song: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
    _emitState();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.play();
    _emitState();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _currentSongController.add(null);
    _emitState();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _emitState();
  }

  /// Set playlist and play from specific index
  Future<void> setPlaylist(List<Song> songs, int startIndex) async {
    _originalPlaylist = List.from(songs);
    _currentIndex = startIndex;

    if (_isShuffled) {
      final currentSong = _originalPlaylist[startIndex];
      _shuffledPlaylist = List.from(_originalPlaylist)..shuffle();
      _shuffledPlaylist.remove(currentSong);
      _shuffledPlaylist.insert(0, currentSong);
      _currentIndex = 0;
    } else {
      _shuffledPlaylist = List.from(songs);
    }

    await _playSongAtIndex(_currentIndex);
  }

  /// Play song at specific index in active playlist
  Future<void> _playSongAtIndex(int index) async {
    if (index >= 0 && index < _activePlaylist.length) {
      _currentIndex = index;
      await play(_activePlaylist[index]);
    }
  }

  /// Skip to a specific index in the current active playlist (FASE 7.2 optimization)
  Future<void> skipToIndex(int index) async {
    await _playSongAtIndex(index);
  }

  /// Skip to next song
  Future<void> skipToNext() async {
    if (_activePlaylist.isEmpty) return;

    if (_currentIndex < _activePlaylist.length - 1) {
      await _playSongAtIndex(_currentIndex + 1);
    } else {
      // Always loop (no "none" mode)
      await _playSongAtIndex(0);
    }
  }

  /// Skip to previous song
  Future<void> skipToPrevious() async {
    if (_activePlaylist.isEmpty) return;

    // If more than 3 seconds into song, restart it
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      await _playSongAtIndex(_currentIndex - 1);
    } else {
      // Always loop
      await _playSongAtIndex(_activePlaylist.length - 1);
    }
  }

  /// Set repeat mode (all or one)
  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
    await _persistence.setRepeatMode(mode);
    _emitState();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _emitState();
  }

  /// Toggle shuffle - maintains current song
  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    await _persistence.setShuffleMode(_isShuffled);

    if (_originalPlaylist.isEmpty) {
      // Nothing queued yet: only the preference changes
    } else if (_isShuffled) {
      // Shuffle ON: Create shuffled playlist with current song at start
      final currentSong = _originalPlaylist[_currentIndex];
      _shuffledPlaylist = List.from(_originalPlaylist)..shuffle();

      // Move current song to index 0
      _shuffledPlaylist.remove(currentSong);
      _shuffledPlaylist.insert(0, currentSong);
      _currentIndex = 0;
    } else {
      // Shuffle OFF: Restore original order
      final currentSong = _shuffledPlaylist[_currentIndex];
      _currentIndex = _originalPlaylist.indexOf(currentSong);
    }

    _emitState();
  }

  /// Get current song
  Song? getCurrentSong() {
    if (_currentIndex >= 0 && _currentIndex < _activePlaylist.length) {
      return _activePlaylist[_currentIndex];
    }
    return null;
  }

  /// Get playlist
  List<Song> getPlaylist() => List.from(_activePlaylist);

  /// Stream of player state
  Stream<PlayerState> get playerStateStream => _stateController.stream;

  /// Stream of current song
  Stream<Song?> get currentSongStream => _currentSongController.stream;

  /// Update queue without interrupting playback (FASE 7.2)
  /// Used for Play Next functionality
  Future<void> updateQueue(List<Song> newQueue) async {
    if (_isShuffled) {
      _shuffledPlaylist = List.from(newQueue);
    } else {
      _originalPlaylist = List.from(newQueue);
    }
    _emitState();
  }

  /// Reorder queue (FASE 7.2)
  /// Used for drag-and-drop in Current Queue screen
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    // Adjust newIndex if moving down
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Reorder the active playlist
    final queue = List<Song>.from(_activePlaylist);
    final song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);

    // Update current index if needed
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    // Update the appropriate playlist
    if (_isShuffled) {
      _shuffledPlaylist = queue;
    } else {
      _originalPlaylist = queue;
    }

    _emitState();
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
    _stateController.close();
    _currentSongController.close();
  }
}
