import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/book.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

class Synopsis extends StatefulWidget {
  const Synopsis({super.key, this.text});
  final String? text;
  @override
  State<Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<Synopsis> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    if (t == null || t.isEmpty) return Text('Sem sinopse disponível.', style: TextStyle(color: context.pal.text2, fontSize: 13));
    final long = t.length > 280;
    return Column(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: Text(t, maxLines: open || !long ? null : 5, overflow: open || !long ? null : TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.45)),
      ),
      if (long)
        TextButton.icon(
          onPressed: () => setState(() => open = !open),
          iconAlignment: IconAlignment.end,
          icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
          label: Text(open ? 'Ver menos' : 'Ver mais'),
        ),
    ]);
  }
}

String _lang(String c) => const {
      'pt': 'Português', 'por': 'Português', 'en': 'Inglês', 'eng': 'Inglês', 'es': 'Espanhol', 'spa': 'Espanhol',
      'fr': 'Francês', 'fre': 'Francês', 'de': 'Alemão', 'ger': 'Alemão', 'it': 'Italiano', 'ita': 'Italiano',
    }[c] ?? c;

class InfoList extends StatelessWidget {
  const InfoList({super.key, this.publisher, this.year, this.pageCount, this.categories = const [], this.isbn, this.language});
  final String? publisher, year, isbn, language;
  final int? pageCount;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rows = <(IconData, String, String?)>[
      (Icons.account_balance_outlined, 'Editora', publisher),
      (Icons.calendar_today_outlined, 'Ano', year),
      (Icons.description_outlined, 'Páginas', pageCount?.toString()),
      (Icons.sell_outlined, 'Categoria', categories.isEmpty ? null : categories.join(', ')),
      (Icons.qr_code_2_rounded, 'ISBN', isbn),
      (Icons.translate_rounded, 'Idioma', language == null ? null : _lang(language!)),
    ].where((r) => r.$3 != null && r.$3!.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox();
    return Column(children: [
      for (final r in rows)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(r.$1, size: 17, color: p.text2),
            const SizedBox(width: 10),
            Text(r.$2, style: TextStyle(color: p.text2, fontSize: 14)),
            const SizedBox(width: 16),
            Expanded(child: Text(r.$3!, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          ]),
        ),
    ]);
  }
}

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'Não foi possível abrir o link');
}

class LinksList extends StatelessWidget {
  const LinksList({super.key, required this.links});
  final List<BookLink> links;

  static const _titles = {
    LinkKind.read: 'Ler gratuitamente (versão legal)',
    LinkKind.preview: 'Prévia',
    LinkKind.buy: 'Onde encontrar e comprar',
    LinkKind.info: 'Mais informações',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (links.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final kind in [LinkKind.read, LinkKind.preview, LinkKind.buy, LinkKind.info])
        if (links.any((l) => l.kind == kind)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(_titles[kind]!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text2)),
          ),
          for (final l in links.where((l) => l.kind == kind))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: kind == LinkKind.read ? Color.alphaBlend(p.green.withValues(alpha: .14), p.surface) : p.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => openUrl(context, l.url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(children: [
                      Expanded(child: Text(l.label, style: TextStyle(fontWeight: FontWeight.w500, color: kind == LinkKind.read ? p.green : p.text))),
                      Icon(Icons.open_in_new_rounded, size: 17, color: kind == LinkKind.read ? p.green : p.text2),
                    ]),
                  ),
                ),
              ),
            ),
        ],
    ]);
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.green = false});
  final String text;
  final bool green;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: green ? p.green.withValues(alpha: .16) : p.surface2, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: green ? p.green : p.text)),
    );
  }
}

/// "Onde você parou?" — atualiza as páginas lidas.
Future<void> showProgressSheet(BuildContext context, Book book) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProgressSheet(book: book),
  );
}

class _ProgressSheet extends StatefulWidget {
  const _ProgressSheet({required this.book});
  final Book book;
  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  late int pages = widget.book.pagesRead;
  late int total = widget.book.pageCount ?? 0;
  late final pagesCtl = TextEditingController(text: '$pages');
  late final totalCtl = TextEditingController(text: total > 0 ? '$total' : '');

  void setPages(int v) {
    setState(() => pages = total > 0 ? v.clamp(0, total) : (v < 0 ? 0 : v));
    pagesCtl.text = '$pages';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final max = total > 0 ? total : (pages > 1000 ? pages : 1000);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Onde você parou?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(widget.book.title, style: TextStyle(color: p.text2, fontSize: 13)),
        Slider(value: pages.clamp(0, max).toDouble(), max: max.toDouble(), activeColor: p.ink, onChanged: (v) => setPages(v.round())),
        Row(children: [
          Expanded(
            child: TextField(
              controller: pagesCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Página'),
              onChanged: (v) => setState(() => pages = int.tryParse(v) ?? 0),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('de', style: TextStyle(color: p.text2))),
          Expanded(
            child: TextField(
              controller: totalCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total', hintText: '?'),
              onChanged: (v) => setState(() => total = int.tryParse(v) ?? 0),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in [5, 10, 25, 50]) Pill(label: '+$n', onTap: () => setPages(pages + n)),
          if (total > 0) Pill(label: 'Terminei', onTap: () => setPages(total)),
        ]),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final app = context.read<AppState>();
              final done = total > 0 && pages >= total;
              await app.updateBook(widget.book.id, (b) {
                b.pagesRead = pages;
                b.pageCount = total > 0 ? total : null;
                if (done) {
                  b.status = ReadingStatus.read;
                } else if (b.status == ReadingStatus.want && pages > 0) {
                  b.status = ReadingStatus.reading;
                }
              });
              if (context.mounted) {
                Navigator.pop(context);
                toast(context, done ? 'Leitura concluída! 🎉' : 'Progresso atualizado');
              }
            },
            child: const Text('Salvar'),
          ),
        ]),
      ]),
    );
  }
}


/// Onde ler o livro de graça, legalmente:
///  - versões gratuitas achadas automaticamente (Gutenberg, Internet Archive,
///    Wikisource, LibriVox);
///  - MEC Livros e BibliOn (empréstimo com login; o app copia o título e abre);
///  - busca no Open Library.
class FreeLibraries extends StatefulWidget {
  const FreeLibraries({super.key, required this.title, this.authors = const []});
  final String title;
  final List<String> authors;
  @override
  State<FreeLibraries> createState() => _FreeLibrariesState();
}

class _FreeLibrariesState extends State<FreeLibraries> {
  List<BookLink>? found;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().api.freeEditions(widget.title, widget.authors).then((l) {
      if (mounted) setState(() => found = l);
    }).catchError((Object _) {
      if (mounted) setState(() => found = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final author = widget.authors.isNotEmpty ? widget.authors.first : null;
    final query = [widget.title, ?author].join(' ');
    Future<void> copyAndOpen(String name, String url) async {
      await Clipboard.setData(ClipboardData(text: query));
      if (context.mounted) toast(context, 'Título copiado. No $name, cole na busca.');
      if (context.mounted) await openUrl(context, url);
    }

    Widget tile(String name, String sub, Color color, VoidCallback onTap, {bool highlight = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: highlight ? Color.alphaBlend(p.green.withValues(alpha: .14), p.surface) : p.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: highlight ? p.green : null)),
                      Text(sub, style: TextStyle(color: p.text2, fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.open_in_new_rounded, size: 17, color: highlight ? p.green : p.text2),
                ]),
              ),
            ),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Row(children: [
          Expanded(child: Text('Ler grátis em bibliotecas digitais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text2))),
          if (found == null) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.text3)),
        ]),
      ),
      for (final l in found ?? const <BookLink>[])
        tile(l.label, 'Versão gratuita encontrada', p.green, () => openUrl(context, l.url), highlight: true),
      tile('MEC Livros', 'Empréstimo gratuito com sua conta gov.br', const Color(0xFF1351B4),
          () => copyAndOpen('MEC Livros', 'https://meclivros.mec.gov.br')),
      tile('BibliOn', 'Biblioteca digital de SP — empréstimo gratuito com cadastro', const Color(0xFFE8622C),
          () => copyAndOpen('BibliOn', 'https://biblion.org.br')),
      tile('Open Library', 'Leitura e empréstimo gratuitos', const Color(0xFF6A5ACD),
          () => openUrl(context, 'https://openlibrary.org/search?q=${Uri.encodeQueryComponent(query)}')),
    ]);
  }
}
