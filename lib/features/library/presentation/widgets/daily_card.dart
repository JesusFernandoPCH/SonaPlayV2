import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';
import 'package:sonaplay/features/library/domain/daily_pick.dart';
import 'package:sonaplay/features/library/domain/entities/song.dart';
import 'package:sonaplay/features/library/presentation/widgets/artwork.dart';
import 'package:sonaplay/features/player/presentation/player_route.dart';
import 'package:sonaplay/features/player/presentation/providers/player_providers.dart';

/// Whether today's card is still showing; closing it hides it until tomorrow
final dailyCardProvider = NotifierProvider<DailyCardNotifier, bool>(
  DailyCardNotifier.new,
);

class DailyCardNotifier extends Notifier<bool> {
  static const _key = 'daily_dismissed';
  Box get _box => Hive.box('settings_box');

  @override
  bool build() => _box.get(_key) != daySeed(DateTime.now());

  void dismiss() {
    state = false;
    _box.put(_key, daySeed(DateTime.now()));
  }
}

/// Greeting, a phrase and the song of the day, above the song list
class DailyCard extends ConsumerWidget {
  /// The list the song is played from
  final List<Song> songs;
  const DailyCard({super.key, required this.songs});

  /// Picked once a day and kept, so plays and re-sorting don't swap the song
  DailyPick? _todaysPick(DateTime now) {
    final box = Hive.box('settings_box');
    final seed = daySeed(now);
    final saved = box.get('daily_pick') as Map?;
    if (saved != null && saved['day'] == seed) {
      for (final song in songs) {
        if (song.id == saved['id']) {
          return (
            song: song,
            kind: DailyKind.values[saved['kind'] as int],
            phrase:
                dailyPhrases[(saved['phrase'] as int) % dailyPhrases.length],
          );
        }
      }
    }
    final pick = pickDaily(songs, Hive.box('play_counts').toMap().cast(), now);
    if (pick != null) {
      box.put('daily_pick', {
        'day': seed,
        'id': pick.song.id,
        'kind': pick.kind.index,
        'phrase': dailyPhrases.indexOf(pick.phrase),
      });
    }
    return pick;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(dailyCardProvider);
    final now = DateTime.now();
    final pick = visible ? _todaysPick(now) : null;

    return AnimatedSize(
      duration: Motion.slow,
      curve: Motion.enter,
      alignment: Alignment.topCenter,
      child: pick == null
          ? const SizedBox(width: double.infinity)
          : Entrance(
              child: _Card(pick: pick, songs: songs, now: now),
            ),
    );
  }
}

class _Card extends ConsumerWidget {
  final DailyPick pick;
  final List<Song> songs;
  final DateTime now;
  const _Card({required this.pick, required this.songs, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = Hive.box('settings_box').get('user_name') as String?;
    final song = pick.song;
    final isCurrent = ref.watch(currentSongProvider).value?.id == song.id;

    void listen() {
      if (isCurrent) {
        Navigator.push(context, PlayerRoute());
        return;
      }
      final index = songs.indexWhere((s) => s.id == song.id);
      ref.read(audioHandlerProvider).playSong(song, songs, index);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.16),
              scheme.surfaceContainer.withValues(alpha: 0.7),
            ],
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '¡${greeting(now)}${name == null ? '' : ', $name'}!'
                          .toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ocultar hasta mañana',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: const AppIcon(AppIcons.close),
                    onPressed: ref.read(dailyCardProvider.notifier).dismiss,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '«${pick.phrase}»',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: listen,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Artwork(songId: song.id, size: 88, large: true),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Badge(pick.kind),
                                const SizedBox(height: 6),
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
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
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: listen,
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: AppIcon(
                                      isCurrent
                                          ? AppIcons.nowPlaying
                                          : AppIcons.play,
                                      size: 16,
                                      filled: !isCurrent,
                                    ),
                                    label: Text(
                                      isCurrent ? 'Sonando' : 'Escuchar',
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}

class _Badge extends StatelessWidget {
  final DailyKind kind;
  const _Badge(this.kind);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.sparkles, size: 12, color: scheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                switch (kind) {
                  DailyKind.favorite => 'TU FAVORITA DEL DÍA',
                  DailyKind.discover => 'DESCUBRIMIENTO DEL DÍA',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
