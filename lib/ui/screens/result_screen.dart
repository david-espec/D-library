import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/book.dart';
import '../../services/books_api.dart';
import '../../services/format.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_parts.dart';
import '../widgets/common.dart';
import '../widgets/shelf.dart';
import 'book_form_screen.dart';

/// Detalhe de um livro encontrado na pesquisa.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});
  final SearchResult result;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late SearchResult r = widget.result;
  bool loading = true, fav = false, saving = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.details(r).then((full) {
      if (mounted) {
        setState(() {
          r = full;
          loading = false;
        });
      }
    });
  }

  Future<void> add(ReadingStatus status) async {
    setState(() => saving = true);
    final app = context.read<AppState>();
    try {
      final b = await app.addFromResult(r, status: status, favorite: fav);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Adicionado à sua estante', action: 'Abrir', onAction: () => openBook(context, b.id));
    } catch (e) {
      if (mounted) toast(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void askStatus() {
    final p = context.pal;
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Em qual estante?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            for (final (s, sub) in const [
              (ReadingStatus.want, 'Lista de desejos'),
              (ReadingStatus.reading, 'Começo a contar hoje'),
              (ReadingStatus.read, 'Já terminei este livro'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(sub),
                    onTap: () {
                      Navigator.pop(sheet);
                      add(s);
                    },
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    final existing = app.findExisting(key: r.key, isbn13: r.isbn13, title: r.title, authors: r.authors);
    final links = mergeLinks([r.links, shopLinks(title: r.title, authors: r.authors, isbn13: r.isbn13, isbn10: r.isbn10)]);
    return Scaffold(
      appBar: AppBar(actions: [
        if (existing == null)
          IconButton(
            onPressed: () => setState(() => fav = !fav),
            icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? const Color(0xFFE2445C) : null),
            tooltip: 'Favoritar ao adicionar',
          ),
        IconButton(
          onPressed: () => SharePlus.instance.share(ShareParams(
            text: '${r.title}${r.authors.isNotEmpty ? ' — ${r.authors.first}' : ''}\n${links.where((l) => l.kind == LinkKind.info).firstOrNull?.url ?? ''}',
          )),
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'Compartilhar',
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 120), children: [
        Center(
          child: Hero(
            tag: r.key,
            child: CoverImage(title: r.title, author: r.authors.firstOrNull, url: r.coverUrlLarge ?? r.coverUrl, fallbackUrl: r.coverUrl, width: 210, radius: 10),
          ),
        ),
        const SizedBox(height: 22),
        Text(r.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -.4)),
        if (r.subtitle != null) Text(r.subtitle!, style: TextStyle(color: p.text2)),
        const SizedBox(height: 4),
        Text(r.authors.isEmpty ? 'Autor desconhecido' : r.authors.join(', '), style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: p.text2)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (r.rating != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, color: p.star, size: 18),
              Text(' ${fmtRating(r.rating!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (r.ratingsCount != null) Text(' (${r.ratingsCount} avaliações)', style: TextStyle(color: p.text2)),
            ]),
          if (r.categories.isNotEmpty) Tag(r.categories.first),
          if (r.freeDigital) const Tag('Versão digital gratuita', green: true),
        ]),
        const SizedBox(height: 14),
        if (loading && r.description == null) const LinearProgressIndicator(minHeight: 2) else Synopsis(text: r.description),
        const SizedBox(height: 6),
        InfoList(publisher: r.publisher, year: r.year, pageCount: r.pageCount, categories: r.categories, isbn: r.isbn13 ?? r.isbn10, language: r.language),
        FreeLibraries(title: r.title, author: r.authors.firstOrNull),
        LinksList(links: links),
        const SizedBox(height: 8),
        Text('Fonte: ${r.provider == BookSource.google ? 'Google Books' : 'Open Library'}', style: TextStyle(color: p.text3, fontSize: 12)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: existing != null
              ? FilledButton.icon(
                  onPressed: () => openBook(context, existing.id),
                  icon: const Icon(Icons.check_rounded),
                  label: Text('Na sua estante · ${existing.status.label}'),
                )
              : Row(children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: p.surface2, foregroundColor: p.text, minimumSize: const Size(54, 54)),
                    tooltip: 'Revisar antes de salvar',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookFormScreen(fromResult: r, favorite: fav))),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving ? null : askStatus,
                      icon: saving
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.inkText))
                          : const Icon(Icons.bookmark_rounded, size: 19),
                      label: Text(saving ? 'Guardando a capa…' : 'Adicionar à minha biblioteca'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}
