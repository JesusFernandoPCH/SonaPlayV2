import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/theme/app_theme.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_options_sheet.dart';

const _rowHeight = 72.0;

/// Multi-select on its own screen: tap rows to check them, then act on all
/// of them from the dock at the bottom
class SelectionScreen extends ConsumerStatefulWidget {
  final List<Song> songs;
  final String initial;

  /// Where the list was scrolled, so the rows stay where they were
  final double scrollOffset;

  const SelectionScreen({
    super.key,
    required this.songs,
    required this.initial,
    this.scrollOffset = 0,
  });

  @override
  ConsumerState<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends ConsumerState<SelectionScreen> {
  late final _selected = <String>{widget.initial};
  late final _scroll = ScrollController(
    initialScrollOffset: widget.scrollOffset,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  /// Runs [action] on the checked songs (in list order); leaves the screen
  /// unless the action was cancelled
  Future<void> _run(Future<bool> Function(List<Song> songs) action) async {
    final songs = [
      for (final s in widget.songs)
        if (_selected.contains(s.id)) s,
    ];
    if (await action(songs) && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    final all = count == widget.songs.length;
    final container = ProviderScope.containerOf(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: AnimatedSwitcher(
          duration: Motion.quick,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            count == 0
                ? 'Elige canciones'
                : count == 1
                ? '1 seleccionada'
                : '$count seleccionadas',
            key: ValueKey(count),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(
              () => all
                  ? _selected.clear()
                  : _selected.addAll(widget.songs.map((s) => s.id)),
            ),
            child: Text(all ? 'Ninguna' : 'Todas'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            controller: _scroll,
            itemExtent: _rowHeight,
            // Room for the dock
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: widget.songs.length,
            itemBuilder: (context, i) {
              final song = widget.songs[i];
              return _Row(
                song: song,
                checked: _selected.contains(song.id),
                onTap: () => _toggle(song.id),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: count == 0 ? const Offset(0, 1.5) : Offset.zero,
              duration: Motion.slow,
              curve: count == 0 ? Curves.easeInCubic : Motion.settle,
              child: _Dock(
                actions: [
                  (
                    Icons.playlist_add_rounded,
                    'Agregar a',
                    () =>
                        _run((s) => addSongsToPlaylist(context, container, s)),
                  ),
                  (
                    Icons.queue_play_next_rounded,
                    'A continuación',
                    () => _run((s) async {
                      await playSongsNext(context, container, s);
                      return true;
                    }),
                  ),
                  (
                    Icons.share_rounded,
                    'Compartir',
                    () => _run((s) async {
                      await shareSongs(s);
                      return true;
                    }),
                  ),
                  (
                    Icons.visibility_off_rounded,
                    'Ocultar',
                    () => _run((s) async {
                      await hideSongs(context, s);
                      return true;
                    }),
                  ),
                  (
                    Icons.delete_outline_rounded,
                    'Eliminar',
                    () => _run((s) => trashSongs(context, s)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Song song;
  final bool checked;
  final VoidCallback onTap;

  const _Row({required this.song, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.enter,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: checked
              ? scheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              const SizedBox(width: 12),
              _Check(checked: checked),
              const SizedBox(width: 14),
              Artwork(songId: song.id, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: checked ? scheme.primary : null,
                      ),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round check that fills with the accent and pops the tick in
class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: checked,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.enter,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: checked ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        child: AnimatedScale(
          scale: checked ? 1 : 0,
          duration: Motion.medium,
          curve: Motion.settle,
          child: Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  final List<(IconData, String, VoidCallback)> actions;
  const _Dock({required this.actions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          // Opaque: the list scrolls underneath
          color: Color.alphaBlend(barColor(scheme), Colors.black),
          elevation: 8,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                for (final (icon, label, onTap) in actions)
                  Expanded(
                    child: Pressable(
                      pressedScale: 0.9,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
