import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';
import 'package:sonaplay/core/presentation/app_icons.dart';

const _sortFields = [
  ('Título', SortOption.titleAsc, SortOption.titleDesc),
  ('Artista', SortOption.artistAsc, SortOption.artistDesc),
  ('Álbum', SortOption.albumAsc, SortOption.albumDesc),
  ('Duración', SortOption.durationAsc, SortOption.durationDesc),
  ('Fecha de añadido', SortOption.dateAddedAsc, SortOption.dateAddedDesc),
];

/// Pick a field; tapping the selected one flips ascending/descending
void showSortSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final current = ref.watch(sortOptionProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<LibraryView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: LibraryView.compact,
                    icon: AppIcon(AppIcons.viewCompact),
                    label: Text('Compacta'),
                  ),
                  ButtonSegment(
                    value: LibraryView.normal,
                    icon: AppIcon(AppIcons.viewList),
                    label: Text('Normal'),
                  ),
                  ButtonSegment(
                    value: LibraryView.grid,
                    icon: AppIcon(AppIcons.viewGrid),
                    label: Text('Cuadrícula'),
                  ),
                ],
                selected: {ref.watch(libraryViewProvider)},
                onSelectionChanged: (v) =>
                    ref.read(libraryViewProvider.notifier).select(v.first),
              ),
            ),
            const Divider(),
            for (final (label, asc, desc) in _sortFields)
              ListTile(
                title: Text(label),
                selected: current == asc || current == desc,
                trailing: current == asc
                    ? const AppIcon(
                        AppIcons.sortUp,
                        semanticLabel: 'Ascendente',
                      )
                    : current == desc
                    ? const AppIcon(
                        AppIcons.sortDown,
                        semanticLabel: 'Descendente',
                      )
                    : null,
                onTap: () => ref
                    .read(sortOptionProvider.notifier)
                    .select(current == asc ? desc : asc),
              ),
          ],
        ),
      );
    },
  ),
);
