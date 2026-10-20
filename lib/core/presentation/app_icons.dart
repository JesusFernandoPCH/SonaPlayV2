import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sonaplay/core/motion/motion.dart';

/// Icon data from Hugeicons (stroke rounded SVG paths)
typedef AppIconData = List<List<dynamic>>;

/// Every icon the app uses, by meaning, so a swap happens in one place
abstract final class AppIcons {
  // Playback
  static const play = HugeIcons.strokeRoundedPlay;
  static const pause = HugeIcons.strokeRoundedPause;
  static const stop = HugeIcons.strokeRoundedStop;
  static const previous = HugeIcons.strokeRoundedPrevious;
  static const next = HugeIcons.strokeRoundedNext;
  static const shuffle = HugeIcons.strokeRoundedShuffle;
  static const repeat = HugeIcons.strokeRoundedRepeat;
  static const repeatOne = HugeIcons.strokeRoundedRepeatOne01;
  static const favorite = HugeIcons.strokeRoundedFavourite;
  static const queue = HugeIcons.strokeRoundedQueue01;
  static const playNext = HugeIcons.strokeRoundedQueue02;
  static const equalizer = HugeIcons.strokeRoundedSlidersVertical;
  static const sleep = HugeIcons.strokeRoundedMoon02;
  static const speed = HugeIcons.strokeRoundedDashboardSpeed01;
  static const ringtone = HugeIcons.strokeRoundedCallRinging01;
  static const nowPlaying = HugeIcons.strokeRoundedAudioWave01;
  static const sparkles = HugeIcons.strokeRoundedSparkles;
  static const lyrics = HugeIcons.strokeRoundedMicVocal;

  // Library
  static const music = HugeIcons.strokeRoundedMusicNote01;
  static const playlist = HugeIcons.strokeRoundedPlayList;
  static const playlistAdd = HugeIcons.strokeRoundedPlayListAdd;
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const folderOff = HugeIcons.strokeRoundedFolderOff;
  static const library = HugeIcons.strokeRoundedMusicNoteSquare01;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const sort = HugeIcons.strokeRoundedSorting05;
  static const filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const sortUp = HugeIcons.strokeRoundedArrowUp02;
  static const sortDown = HugeIcons.strokeRoundedArrowDown02;
  static const viewCompact = HugeIcons.strokeRoundedMenu01;
  static const viewList = HugeIcons.strokeRoundedListView;
  static const viewGrid = HugeIcons.strokeRoundedGridView;

  // Actions
  static const more = HugeIcons.strokeRoundedMoreVertical;
  static const share = HugeIcons.strokeRoundedShare08;
  static const edit = HugeIcons.strokeRoundedEdit02;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const hide = HugeIcons.strokeRoundedViewOff;
  static const show = HugeIcons.strokeRoundedView;
  static const add = HugeIcons.strokeRoundedAdd01;
  static const check = HugeIcons.strokeRoundedTick02;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const drag = HugeIcons.strokeRoundedDragDropVertical;
  static const collapse = HugeIcons.strokeRoundedArrowDown01;
  static const chevronRight = HugeIcons.strokeRoundedArrowRight01;

  // Settings and appearance
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const palette = HugeIcons.strokeRoundedPaintBoard;
  static const image = HugeIcons.strokeRoundedImage01;
  static const imageAdd = HugeIcons.strokeRoundedImageAdd01;
  static const blur = HugeIcons.strokeRoundedBlur;
  static const dim = HugeIcons.strokeRoundedContrast;
  static const timer = HugeIcons.strokeRoundedTimer02;
  static const info = HugeIcons.strokeRoundedInformationCircle;
  static const battery = HugeIcons.strokeRoundedBatteryWarning;
  static const update = HugeIcons.strokeRoundedInstallingUpdates01;
}

/// A Hugeicon that takes its size and color from the surrounding IconTheme
/// (like [Icon]), optionally filled in
class AppIcon extends StatelessWidget {
  final AppIconData icon;
  final double? size;
  final Color? color;

  /// Fills closed shapes (a solid heart, play or pause)
  final bool filled;

  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.filled = false,
    this.semanticLabel,
  });

  static final _filledCache = Expando<AppIconData>();

  static AppIconData _filledOf(AppIconData icon) => _filledCache[icon] ??= [
    for (final element in icon)
      [
        element[0],
        {...(element[1] as Map<String, dynamic>), 'fill': 'currentColor'},
      ],
  ];

  @override
  Widget build(BuildContext context) {
    final glyph = HugeIcon(
      icon: filled ? _filledOf(icon) : icon,
      size: size,
      color: color,
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(
            label: semanticLabel,
            child: ExcludeSemantics(child: glyph),
          );
  }
}

/// Swaps icons with a springy pop (play/pause, favorite, repeat modes)
class SwapIcon extends StatelessWidget {
  final AppIconData icon;
  final bool filled;
  final double? size;
  final Color? color;

  const SwapIcon(
    this.icon, {
    super.key,
    this.filled = false,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.medium,
    switchInCurve: Motion.settle,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) => ScaleTransition(
      scale: animation,
      child: FadeTransition(opacity: animation, child: child),
    ),
    child: AppIcon(
      icon,
      key: ValueKey((icon, filled)),
      filled: filled,
      size: size,
      color: color,
    ),
  );
}
