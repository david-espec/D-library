import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/text_utils.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/shelf.dart';

class ShelfDef {
  final String id, label;
  final bool Function(Book) test;
  const ShelfDef(this.id, this.label, this.test);
}

final shelves = <ShelfDef>[
  ShelfDef('all', 'Todos', (_) => true),
  ShelfDef('fav', 'Favoritos', (b) => b.favorite),
  ShelfDef('want', 'Quero ler', (b) => b.status == ReadingStatus.want),
  ShelfDef('reading', 'Lendo', (b) => b.status == ReadingStatus.reading),
  ShelfDef('read', 'Lidos', (b) => b.status == ReadingStatus.read),
  ShelfDef('abandoned', 'Abandonados', (b) => b.status == ReadingStatus.abandoned),
  ShelfDef('manual', 'Adicionados manualmente', (b) => b.isManual),
];

enum SortBy {
  recent('Recentes'),
  title('Título'),
  author('Autor'),
  rating('Avaliação'),
  activity('Atividade');

  const SortBy(this.label);
  final String label;

  int compare(Book a, Book b) => switch (this) {
        SortBy.recent => b.createdAt.compareTo(a.createdAt),
        SortBy.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        SortBy.author => (a.firstAuthor.isEmpty ? '~' : a.firstAuthor).compareTo(b.firstAuthor.isEmpty ? '~' : b.firstAuthor),
        SortBy.rating => b.rating.compareTo(a.rating),
        SortBy.activity => b.updatedAt.compareTo(a.updatedAt),
      };
}

/// Estante completa com categorias, ordenação e filtros.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialShelf = 'all'});
  final String initialShelf;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late String shelf = widget.initialShelf;
  SortBy sort = SortBy.recent;
  String filter = '';
  String? genre;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final books = context.watch<AppState>().books;
    final current = shelves.firstWhere((s) => s.id == shelf, orElse: () => shelves.first);
    final inShelf = books.where(current.test).toList();
    final gc = <String, int>{};
    for (final b in inShelf) {
      if (b.categories.isNotEmpty) gc[b.categories.first] = (gc[b.categories.first] ?? 0) + 1;
    }
    final genres = gc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final q = norm(filter);
    final list = inShelf
        .where((b) => genre == null || (b.categories.isNotEmpty && b.categories.first == genre))
        .where((b) => q.isEmpty || norm('${b.title} ${b.authors.join(' ')} ${b.publisher ?? ''} ${b.isbn13 ?? ''}').contains(q))
        .toList()
      ..sort(sort.compare);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha estante'),
        actions: [
          PopupMenuButton<SortBy>(
            initialValue: sort,
            onSelected: (s) => setState(() => sort = s),
            itemBuilder: (_) => [for (final s in SortBy.values) PopupMenuItem(value: s, child: Text(s.label))],
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(999)),
              child: Row(children: [const Icon(Icons.swap_vert_rounded, size: 17), const SizedBox(width: 4), Text(sort.label, style: const TextStyle(fontSize: 13))]),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: shelves.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Pill(
              label: shelves[i].label,
              count: books.where(shelves[i].test).length,
              selected: shelves[i].id == shelf,
              onTap: () => setState(() {
                shelf = shelves[i].id;
                genre = null;
              }),
            ),
          ),
        ),
        if (inShelf.length > 6)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              onChanged: (v) => setState(() => filter = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Filtrar nesta estante…', isDense: true),
            ),
          ),
        if (genres.length > 1)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              itemCount: genres.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Pill(
                small: true,
                label: '${genres[i].key} · ${genres[i].value}',
                selected: genre == genres[i].key,
                onTap: () => setState(() => genre = genre == genres[i].key ? null : genres[i].key),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (list.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Shelf(books: list))
        else
          Padding(
            padding: const EdgeInsets.all(40),
            child: Text(inShelf.isEmpty ? 'Nenhum livro em “${current.label}” ainda.' : 'Nenhum livro corresponde ao filtro.',
                textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
          ),
      ]),
    );
  }
}
