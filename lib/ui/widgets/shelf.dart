import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../screens/book_screen.dart';
import '../theme.dart';
import 'common.dart';

/// Abre o livro com uma transição suave.
void openBook(BuildContext context, String id) {
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => BookScreen(id: id),
    transitionsBuilder: (_, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  ));
}

class _Plank extends StatelessWidget {
  const _Plank();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.wood1, p.wood2]),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 8), spreadRadius: -6)],
      ),
    );
  }
}

/// Um livro na prateleira (capa, favorito e barra de progresso).
class ShelfBook extends StatefulWidget {
  const ShelfBook({super.key, required this.book, this.index = 0});
  final Book book;
  final int index;
  @override
  State<ShelfBook> createState() => _ShelfBookState();
}

class _ShelfBookState extends State<ShelfBook> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _down = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.index * 35).clamp(0, 500)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final f = b.status == ReadingStatus.reading ? b.progressFraction : null;
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .12), end: Offset.zero).animate(anim),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: () => openBook(context, b.id),
          child: AnimatedScale(
            scale: _down ? .95 : 1,
            duration: const Duration(milliseconds: 120),
            child: Semantics(
              label: b.title,
              button: true,
              child: Stack(children: [
                CoverImage.book(context, b),
                if (b.favorite)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: Color(0xEBFFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFE2445C)),
                    ),
                  ),
                if (f != null)
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: f, minHeight: 4, backgroundColor: const Color(0x73FFFFFF), color: Colors.white),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estante em fileiras, cada uma apoiada numa prateleira.
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth < 400 ? 3 : c.maxWidth < 640 ? 4 : c.maxWidth < 900 ? 5 : 6;
      final rows = <List<Book>>[];
      for (var i = 0; i < books.length; i += perRow) {
        rows.add(books.sublist(i, (i + perRow).clamp(0, books.length)));
      }
      return Column(children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < perRow; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: i < rows[r].length ? ShelfBook(book: rows[r][i], index: r * perRow + i) : const SizedBox()),
                  ],
                ]),
              ),
              const _Plank(),
            ]),
          ),
      ]);
    });
  }
}

/// Fileira horizontal rolável (tela inicial).
class ShelfStrip extends StatelessWidget {
  const ShelfStrip({super.key, required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) => Align(alignment: Alignment.bottomCenter, child: SizedBox(width: 100, child: ShelfBook(book: books[i], index: i))),
        ),
      ),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: _Plank()),
    ]);
  }
}
