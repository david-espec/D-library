import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/format.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_parts.dart';
import '../widgets/common.dart';
import '../widgets/shelf.dart';
import 'library_screen.dart';
import 'scan_screen.dart';
import 'shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _shelf(BuildContext context, String id) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryScreen(initialShelf: id)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = context.pal;
    final books = app.books;
    final s = Stats.of(books);
    final reading = books.where((b) => b.status == ReadingStatus.reading).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = books.where((b) => b.status != ReadingStatus.want).take(12).toList();
    final favs = books.where((b) => b.favorite).take(12).toList();
    final want = books.where((b) => b.status == ReadingStatus.want).take(12).toList();
    final goal = app.settings.yearlyGoal;
    final goalPct = (s.readThisYear / (goal < 1 ? 1 : goal)).clamp(0.0, 1.0);

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 30), children: [
        for (final w in <Widget>[
        Row(children: [
          Icon(Icons.menu_book_outlined, size: 30, color: p.text),
          const SizedBox(width: 10),
          Expanded(child: Text('D Libery', style: serif.copyWith(fontSize: 32, color: p.text))),
          IconButton(onPressed: () => Shell.of(context)?.go(3), icon: const Icon(Icons.settings_outlined), tooltip: 'Configurações'),
        ]),
        const SizedBox(height: 10),
        Material(
          color: p.surface2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Shell.of(context)?.go(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(Icons.search_rounded, color: p.text2),
                const SizedBox(width: 10),
                Text('Pesquisar livros…', style: TextStyle(color: p.text2, fontSize: 15)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        StatCard(items: [
          (Icons.menu_book_outlined, fmtInt(s.total), s.total == 1 ? 'Livro' : 'Livros'),
          (Icons.bar_chart_rounded, fmtInt(s.pagesRead), 'Páginas lidas'),
          (Icons.emoji_events_outlined, s.avgRating > 0 ? fmtRating(s.avgRating) : '–', 'Avaliação média'),
        ]),
        if (books.isEmpty)
          const _Empty()
        else ...[
          if (reading.isNotEmpty) ...[
            SectionHeader('Lendo agora', action: 'Ver mais', onAction: () => _shelf(context, 'reading')),
            for (final b in reading.take(3)) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReadingCard(book: b)),
          ],
          if (recent.isNotEmpty) ...[
            SectionHeader('Sua biblioteca', action: 'Ver mais', onAction: () => _shelf(context, 'all')),
            ShelfStrip(books: recent),
          ],
          if (favs.isNotEmpty) ...[
            SectionHeader('Favoritos', action: 'Ver mais', onAction: () => _shelf(context, 'fav')),
            ShelfStrip(books: favs),
          ],
          if (want.isNotEmpty) ...[
            SectionHeader('Quero ler', action: 'Ver mais', onAction: () => _shelf(context, 'want')),
            ShelfStrip(books: want),
          ],
          SectionHeader('Meta de ${DateTime.now().year}', action: 'Detalhes', onAction: () => Shell.of(context)?.go(2)),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${s.readThisYear} de $goal livros', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                Text(goalPct >= 1 ? 'Meta batida! 🎉' : 'Faltam ${goal - s.readThisYear}', style: TextStyle(color: p.text2, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              ProgressLine(value: goalPct, height: 9),
            ]),
          ),
        ],
        ]) w is ShelfStrip ? w : Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: w),
      ]),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.book});
  final Book book;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final f = book.progressFraction;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: () => openBook(context, book.id),
            child: Row(children: [
              CoverImage.book(context, book, width: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(book.firstAuthor.isEmpty ? 'Autor desconhecido' : book.firstAuthor, style: TextStyle(color: p.text2, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ProgressLine(value: f ?? 0)),
                    const SizedBox(width: 10),
                    Text(f != null ? '${(f * 100).round()}%' : 'p. ${book.pagesRead}', style: TextStyle(color: p.text2, fontSize: 12)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: p.ink, foregroundColor: p.inkText),
          onPressed: () => showProgressSheet(context, book),
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Atualizar progresso',
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        SizedBox(
          height: 96,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (c, h) in const [(Color(0xFFC86B4C), 70.0), (Color(0xFF3D5A80), 86.0), (Color(0xFFD9B44A), 62.0), (Color(0xFF4F7A5A), 78.0)])
                Container(width: 20, height: h, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
            ]),
            Container(width: 140, height: 10, color: p.wood2),
          ]),
        ),
        const SizedBox(height: 18),
        Text('Sua estante está esperando', style: serif.copyWith(fontSize: 28, color: p.text)),
        const SizedBox(height: 8),
        Text('Fotografe a capa de um livro ou pesquise pelo título para começar sua coleção.',
            textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Fotografar capa'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.surface2, foregroundColor: p.text),
            onPressed: () => Shell.of(context)?.go(1),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Pesquisar'),
          ),
        ]),
      ]),
    );
  }
}
