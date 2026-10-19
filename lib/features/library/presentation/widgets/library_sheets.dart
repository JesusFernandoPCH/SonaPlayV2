import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonaplay/features/library/domain/entities/sort_option.dart';
import 'package:sonaplay/features/library/presentation/providers/library_providers.dart';

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
            for (final (label, asc, desc) in _sortFields)
              ListTile(
                title: Text(label),
                selected: current == asc || current == desc,
                trailing: current == asc
                    ? const Icon(
                        Icons.arrow_upward_rounded,
                        semanticLabel: 'Ascendente',
                      )
                    : current == desc
                    ? const Icon(
                        Icons.arrow_downward_rounded,
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

/// Artist and album filters, listing only values present in the library
void showFilterSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final songs = ref.watch(visibleSongsProvider).value ?? const [];
      final filter = ref.watch(libraryFilterProvider);
      final notifier = ref.read(libraryFilterProvider.notifier);
      List<String> unique(Iterable<String?> values) =>
          (values.whereType<String>().toSet().toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));

      Widget row(
        String label,
        Iterable<String?> values,
        String? selected,
        void Function(String?) onSelected,
      ) => ListTile(
        title: Text(label),
        subtitle: Text(selected ?? 'Todos'),
        trailing: selected == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                tooltip: 'Quitar filtro de ${label.toLowerCase()}',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => onSelected(null),
              ),
        onTap: () async {
          final picked = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _ValuePicker(title: label, values: unique(values)),
            ),
          );
          if (picked != null) onSelected(picked);
        },
      );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Filtros',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            row(
              'Artista',
              songs.map((s) => s.artist),
              filter.artist,
              (v) => notifier.apply((artist: v, album: filter.album)),
            ),
            row(
              'Álbum',
              songs.map((s) => s.album),
              filter.album,
              (v) => notifier.apply((artist: filter.artist, album: v)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => notifier.apply((artist: null, album: null)),
                child: const Text('Quitar filtros'),
              ),
            ),
          ],
        ),
      );
    },
  ),
);

/// Full-screen list with a search box; pops with the chosen value
class _ValuePicker extends StatefulWidget {
  final String title;
  final List<String> values;
  const _ValuePicker({required this.title, required this.values});

  @override
  State<_ValuePicker> createState() => _ValuePickerState();
}

class _ValuePickerState extends State<_ValuePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.values
        : widget.values.where((v) => v.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Buscar ${widget.title.toLowerCase()}',
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
      ),
      body: shown.isEmpty
          ? const Center(child: Text('Sin resultados'))
          : ListView.builder(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(shown[i]),
                onTap: () => Navigator.pop(context, shown[i]),
              ),
            ),
    );
  }
}
