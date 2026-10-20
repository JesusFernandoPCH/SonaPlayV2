import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/core/motion/motion.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/features/library/presentation/screens/folders_tab.dart';
import 'package:sonaplay/features/library/presentation/screens/playlists_tab.dart';
import 'package:sonaplay/features/library/presentation/screens/search_screen.dart';
import 'package:sonaplay/features/library/presentation/widgets/daily_card.dart';
import 'package:sonaplay/features/library/presentation/widgets/library_sheets.dart';
import 'package:sonaplay/features/library/presentation/widgets/song_list_view.dart';
import 'package:sonaplay/features/player/presentation/widgets/mini_player.dart';
import 'package:sonaplay/features/settings/presentation/settings_screen.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

const _sections = [
  (label: 'Canciones', icon: AppIcons.music, selected: AppIcons.music),
  (label: 'Playlists', icon: AppIcons.playlist, selected: AppIcons.queue),
  (label: 'Favoritas', icon: AppIcons.favorite, selected: AppIcons.favorite),
  (label: 'Carpetas', icon: AppIcons.folder, selected: AppIcons.folder),
];

/// Home: the four library sections behind a bottom navigation bar
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  var _section = 0;
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int section) =>
      _pages.animateToPage(section, duration: Motion.slow, curve: Motion.enter);

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final onSongs = _section == 0;
    final librarySongs = ref.watch(librarySongsProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          _sections[_section].label,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const AppIcon(AppIcons.search),
            onPressed: () => _open(const SearchScreen()),
          ),
          if (onSongs)
            IconButton(
              tooltip: 'Ordenar',
              icon: const AppIcon(AppIcons.sort),
              onPressed: () => showSortSheet(context),
            ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const AppIcon(AppIcons.settings),
            onPressed: () => _open(const SettingsScreen()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Swipe sideways between sections; each keeps its scroll position
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _section = i),
        children: [
          for (final page in [
            SongListView(
              songs: librarySongs,
              emptyText: 'No encontramos canciones en este teléfono',
              banner: DailyCard(songs: librarySongs.value ?? const []),
            ),
            const PlaylistsTab(),
            SongListView(
              songs: ref.watch(favoriteSongsProvider),
              emptyText:
                  'Toca el corazón en el reproductor para guardar favoritas',
            ),
            const FoldersTab(),
          ])
            _KeepAlive(child: page),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(aboveNavigation: true),
          NavigationBar(
            selectedIndex: _section,
            onDestinationSelected: _goTo,
            destinations: [
              for (final s in _sections)
                NavigationDestination(
                  icon: AppIcon(s.icon),
                  selectedIcon: AppIcon(s.selected),
                  label: s.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Keeps a page alive (and its scroll position) while another is shown
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
