import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/book.dart';
import '../../services/format.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_parts.dart';
import '../widgets/common.dart';
import 'book_form_screen.dart';

/// Um livro da sua estante: status, progresso, datas, avaliação e anotações.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.id});
  final String id;
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final notes = TextEditingController();
  final notesFocus = FocusNode();
  bool _loadedNotes = false;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    notesFocus.addListener(() {
      if (!notesFocus.hasFocus) _saveNotes(showToast: true);
    });
  }

  @override
  void dispose() {
    _saveNotes(); // ao sair da tela, salva sem avisar
    notes.dispose();
    notesFocus.dispose();
    super.dispose();
  }

  void _saveNotes({bool showToast = false}) {
    final b = _app.byId(widget.id);
    if (b != null && b.notes != notes.text) {
      _app.updateBook(b.id, (x) => x.notes = notes.text);
      if (showToast && mounted) toast(context, 'Anotações salvas');
    }
  }

  Future<void> _pickDate(Book b, bool start) async {
    final app = context.read<AppState>();
    final init = parseIso(start ? b.startedAt : b.finishedAt) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: start ? 'Comecei em' : 'Terminei em',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (d == null) return;
    await app.updateBook(b.id, (x) {
      if (start) {
        x.startedAt = isoDate(d);
      } else {
        x.finishedAt = isoDate(d);
        x.status = ReadingStatus.read;
      }
    });
  }

  Future<void> _delete(Book b) async {
    final ok = await confirm(context,
        title: 'Remover este livro?', text: '“${b.title}” sai da sua estante, junto com suas anotações e a capa guardada.', ok: 'Remover', danger: true);
    if (!ok || !mounted) return;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    notes.text = b.notes; // não salvar de novo ao sair
    final removed = await app.removeBook(b.id);
    if (!mounted) return;
    Navigator.pop(context);
    if (removed != null) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Livro removido'),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => app.restoreBook(removed.$1, removed.$2)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = context.pal;
    final b = app.byId(widget.id);
    if (b == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('Este livro não está mais na sua estante.', style: TextStyle(color: p.text2))));
    }
    if (!_loadedNotes) {
      notes.text = b.notes;
      _loadedNotes = true;
    }
    final f = b.progressFraction;

    Widget dateBox(String label, String? iso, bool start) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickDate(b, start),
            onLongPress: iso == null ? null : () => app.updateBook(b.id, (x) => start ? x.startedAt = null : x.finishedAt = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 12, color: p.text2)),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(child: Text(iso == null ? '—' : fmtDate(iso), style: const TextStyle(fontWeight: FontWeight.w600))),
                  Icon(Icons.calendar_today_outlined, size: 16, color: p.text2),
                ]),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          onPressed: () => app.toggleFavorite(b.id),
          icon: Icon(b.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: b.favorite ? const Color(0xFFE2445C) : null),
          tooltip: 'Favorito',
        ),
        IconButton(
          onPressed: () => SharePlus.instance.share(ShareParams(
            text: '${b.title}${b.authors.isNotEmpty ? ' — ${b.authors.first}' : ''}\n${b.links.where((l) => l.kind == LinkKind.info).firstOrNull?.url ?? ''}',
          )),
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'Compartilhar',
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookFormScreen(editId: b.id))),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Editar',
        ),
      ]),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 40), children: [
          Center(child: CoverImage.book(context, b, width: 210, radius: 10)),
          const SizedBox(height: 22),
          Text(b.title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -.4)),
          if (b.subtitle != null) Text(b.subtitle!, style: TextStyle(color: p.text2)),
          const SizedBox(height: 4),
          Text(b.authors.isEmpty ? 'Autor desconhecido' : b.authors.join(', '), style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: p.text2)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (b.categories.isNotEmpty) Tag(b.categories.first),
            if (b.isManual) const Tag('Cadastro manual'),
          ]),
          const SizedBox(height: 16),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Status da leitura', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Segmented<ReadingStatus>(
                values: ReadingStatus.values,
                value: b.status,
                label: (s) => s.label,
                onChanged: (s) => app.updateBook(b.id, (x) => x.status = s),
              ),
              if (b.status == ReadingStatus.reading || b.pagesRead > 0) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => showProgressSheet(context, b),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: Text(f != null ? '${(f * 100).round()}% lido' : '${fmtInt(b.pagesRead)} páginas lidas',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text('${fmtInt(b.pagesRead)}${b.pageCount != null ? ' / ${fmtInt(b.pageCount!)}' : ''} pág. · ', style: TextStyle(color: p.text2, fontSize: 13)),
                      Text('atualizar', style: TextStyle(color: p.text2, fontSize: 13, decoration: TextDecoration.underline)),
                    ]),
                    const SizedBox(height: 8),
                    ProgressLine(value: f ?? 0, height: 9),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [dateBox('Comecei em', b.startedAt, true), const SizedBox(width: 10), dateBox('Terminei em', b.finishedAt, false)]),
              if (b.status == ReadingStatus.read && b.startedAt != null && b.finishedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Lido de ${fmtDate(b.startedAt)} a ${fmtDate(b.finishedAt)}.', style: TextStyle(color: p.text2, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              const Text('Minha avaliação', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Stars(value: b.rating, size: 32, onChanged: (v) => app.updateBook(b.id, (x) => x.rating = v)),
              const SizedBox(height: 18),
              const Text('Anotações', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                focusNode: notesFocus,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'O que achou? Trechos favoritos, ideias…'),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Sinopse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Synopsis(text: b.description),
          InfoList(publisher: b.publisher, year: b.year, pageCount: b.pageCount, categories: b.categories, isbn: b.isbn13 ?? b.isbn10, language: b.language),
          FreeLibraries(title: b.title, author: b.authors.firstOrNull),
          LinksList(links: b.links),
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: p.danger, backgroundColor: p.danger.withValues(alpha: .08), minimumSize: const Size.fromHeight(48)),
            onPressed: () => _delete(b),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remover da estante'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Adicionado em ${fmtDate(isoDate(DateTime.fromMillisecondsSinceEpoch(b.createdAt)))}', style: TextStyle(color: p.text3, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
