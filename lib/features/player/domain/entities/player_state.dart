/// Repeat mode for playback
enum RepeatMode {
  /// Repeat entire playlist
  all,

  /// Repeat current song only
  one,
}

/// Player state entity representing current playback status
class PlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffled;
  final RepeatMode repeatMode;

  const PlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.all, // Default to ALL
  });

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffled,
    RepeatMode? repeatMode,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}
