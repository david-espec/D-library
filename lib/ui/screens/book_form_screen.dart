import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/format.dart';
import '../../services/isbn.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/shelf.dart';

const _genres = [
  'Ficção', 'Romance', 'Fantasia', 'Ficção científica', 'Mistério', 'Suspense', 'Terror', 'História', 'Biografia', 'Filosofia',
  'Psicologia', 'Autoajuda', 'Negócios', 'Ciência', 'Poesia', 'Clássicos', 'Infantojuvenil', 'Quadrinhos', 'Religião', 'Política',
  'Tecnologia', 'Arte', 'Culinária', 'Viagem', 'Educação',
];
const _manualLinkLabel = 'Versão digital (link salvo)';

enum _CoverMode { keep, photo, remote, none }

/// Cadastro (novo livro) ou edição.
class BookFormScreen extends StatefulWidget {
  const BookFormScreen({super.key, this.editId, this.draft, this.fromResult, this.photoPath, this.favorite = false});
  final String? editId;
  final NewBook? draft;
  final SearchResult? fromResult;
  final String? photoPath;
  final bool favorite;
  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  late final AppState app = context.read<AppState>();
  late final Book? editing = widget.editId != null ? app.byId(widget.editId!) : null;
  late final SearchResult? fr = widget.fromResult;

  late final title = TextEditingController();
  late final subtitle = TextEditingController();
  late final authors = TextEditingController();
  late final publisher = TextEditingController();
  late final year = TextEditingController();
  late final pages = TextEditingController();
  late final isbn = TextEditingController();
  late final categories = TextEditingController();
  late final description = TextEditingController();
  late final notes = TextEditingController();
  late final pagesRead = TextEditingController();
  late final link = TextEditingController();
  ReadingStatus status = ReadingStatus.want;
  bool favorite = false;
  double rating = 0;
  String? startedAt, finishedAt;
  String? photo;
  late _CoverMode cover;
  bool saving = false, looking = false;
  final _genreFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final e = editing;
    final d = widget.draft ?? (fr != null ? NewBook.fromResult(fr!) : null);
    title.text = e?.title ?? d?.title ?? '';
    subtitle.text = e?.subtitle ?? d?.subtitle ?? '';
    authors.text = (e?.authors ?? d?.authors ?? const []).join(', ');
    publisher.text = e?.publisher ?? d?.publisher ?? '';
    year.text = e?.year ?? d?.year ?? '';
    final pc = e?.pageCount ?? d?.pageCount;
    pages.text = pc?.toString() ?? '';
    isbn.text = e?.isbn13 ?? e?.isbn10 ?? d?.isbn13 ?? d?.isbn10 ?? '';
    categories.text = (e?.categories ?? d?.categories ?? const []).join(', ');
    description.text = e?.description ?? d?.description ?? '';
    notes.text = e?.notes ?? '';
    status = e?.status ?? d?.status ?? ReadingStatus.want;
    favorite = e?.favorite ?? widget.favorite;
    rating = e?.rating ?? 0;
    startedAt = e?.startedAt;
    finishedAt = e?.finishedAt;
    pagesRead.text = (e?.pagesRead ?? 0) > 0 ? '${e!.pagesRead}' : '';
    link.text = (e?.links ?? const <BookLink>[]).where((l) => l.label == _manualLinkLabel).firstOrNull?.url ?? '';
    photo = widget.photoPath;
    final remote = fr?.coverUrlLarge ?? fr?.coverUrl;
    cover = e != null ? _CoverMode.keep : remote != null ? _CoverMode.remote : photo != null ? _CoverMode.photo : _CoverMode.none;
  }

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1000, imageQuality: 86);
    if (x != null) {
      setState(() {
        photo = x.path;
        cover = _CoverMode.photo;
      });
    }
  }

  Future<void> _fillFromIsbn() async {
    final code = asIsbn(isbn.text);
    if (code == null) return toast(context, 'ISBN inválido');
    setState(() => looking = true);
    try {
      final rs = await app.api.lookupIsbn(code);
      if (rs.isEmpty) {
        if (mounted) toast(context, 'Nenhum livro encontrado com esse ISBN');
        return;
      }
      final r = rs.first;
      void fill(TextEditingController c, String? v) {
        if (c.text.trim().isEmpty && v != null) c.text = v;
      }
      fill(title, r.title);
      fill(subtitle, r.subtitle);
      fill(authors, r.authors.join(', '));
      fill(publisher, r.publisher);
      fill(year, r.year);
      fill(pages, r.pageCount?.toString());
      fill(categories, r.categories.join(', '));
      fill(description, r.description);
      if (mounted) toast(context, 'Informações preenchidas pelo ISBN');
    } catch (_) {
      if (mounted) toast(context, 'Sem conexão com as fontes de livros');
    } finally {
      if (mounted) setState(() => looking = false);
    }
  }

  List<String> _split(String s) => s.split(RegExp(r'[,;]')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  Future<void> _save() async {
    if (title.text.trim().isEmpty) return toast(context, 'Informe pelo menos o título');
    setState(() => saving = true);
    try {
      final cleaned = cleanIsbn(isbn.text);
      final isbn13 = asIsbn(cleaned) ?? (cleaned.length == 13 ? cleaned : null);
      final base = (editing?.links ?? fr?.links ?? const <BookLink>[]).where((l) => l.label != _manualLinkLabel).toList();
      var url = link.text.trim();
      if (url.isNotEmpty && !url.startsWith('http')) url = 'https://$url';
      final links = url.isEmpty ? base : mergeLinks([[BookLink(LinkKind.read, _manualLinkLabel, url)], base]);
      final pr = int.tryParse(pagesRead.text) ?? 0;

      if (editing != null) {
        List<int>? newCover;
        if (cover == _CoverMode.photo && photo != null) newCover = await File(photo!).readAsBytes();
        if (cover == _CoverMode.none) newCover = const [];
        await app.updateBook(editing!.id, (b) {
          b
            ..title = title.text.trim()
            ..subtitle = subtitle.text.trim().isEmpty ? null : subtitle.text.trim()
            ..authors = _split(authors.text)
            ..publisher = publisher.text.trim().isEmpty ? null : publisher.text.trim()
            ..year = year.text.trim().isEmpty ? null : year.text.trim()
            ..pageCount = int.tryParse(pages.text)
            ..isbn13 = isbn13
            ..isbn10 = isbn13 == null && cleaned.length == 10 ? cleaned : null
            ..categories = _split(categories.text)
            ..description = description.text.trim().isEmpty ? null : description.text.trim()
            ..links = links
            ..status = status
            ..favorite = favorite
            ..rating = rating
            ..notes = notes.text
            ..pagesRead = pr
            ..startedAt = startedAt
            ..finishedAt = finishedAt;
          if (cover == _CoverMode.none) b.coverUrl = null;
        }, newCover: newCover);
        if (mounted) {
          toast(context, 'Alterações salvas');
          Navigator.pop(context);
        }
        return;
      }

      List<int>? bytes;
      String? remoteUrl;
      if (cover == _CoverMode.photo && photo != null) bytes = await File(photo!).readAsBytes();
      if (cover == _CoverMode.remote && fr != null) {
        bytes = await app.api.downloadImage([fr!.coverUrlLarge, fr!.coverUrl]);
        if (bytes == null) remoteUrl = fr!.coverUrlLarge ?? fr!.coverUrl;
      }
      final authorsList = _split(authors.text);
      final dup = app.findExisting(isbn13: isbn13, title: title.text.trim(), authors: authorsList);
      final book = await app.addBook(NewBook(
        title: title.text.trim(),
        subtitle: subtitle.text.trim().isEmpty ? null : subtitle.text.trim(),
        authors: authorsList,
        publisher: publisher.text.trim().isEmpty ? null : publisher.text.trim(),
        year: year.text.trim().isEmpty ? null : year.text.trim(),
        pageCount: int.tryParse(pages.text),
        isbn13: isbn13,
        isbn10: isbn13 == null && cleaned.length == 10 ? cleaned : null,
        categories: _split(categories.text),
        description: description.text.trim().isEmpty ? null : description.text.trim(),
        language: fr?.language,
        links: links,
        origin: fr?.provider.name ?? 'manual',
        originId: fr?.providerId,
        coverBytes: bytes,
        coverUrl: remoteUrl,
        status: status,
        favorite: favorite,
        rating: rating,
        notes: notes.text,
        pagesRead: pr,
        startedAt: startedAt,
        finishedAt: finishedAt,
      ));
      if (!mounted) return;
      toast(context, dup != null ? 'Salvo (você já tinha um livro parecido na estante)' : 'Livro salvo na sua estante');
      Navigator.of(context).popUntil((r) => r.isFirst);
      openBook(context, book.id);
    } catch (e) {
      if (mounted) toast(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _date(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: parseIso(start ? startedAt : finishedAt) ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      cancelText: 'Cancelar',
    );
    if (d != null) setState(() => start ? startedAt = isoDate(d) : finishedAt = isoDate(d));
  }

  Widget _row(String label, TextEditingController c, {TextInputType? kb, String hint = '—', Widget? trailing, List<String>? suggestions}) {
    final p = context.pal;
    final field = suggestions == null
        ? TextField(
            controller: c,
            keyboardType: kb,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint, filled: false, border: InputBorder.none, focusedBorder: InputBorder.none, isDense: true),
          )
        : RawAutocomplete<String>(
            textEditingController: c,
            focusNode: _genreFocus,
            optionsBuilder: (v) => v.text.isEmpty ? const <String>[] : suggestions.where((s) => s.toLowerCase().startsWith(v.text.toLowerCase())),
            fieldViewBuilder: (ctx, ctl, focus, _) => TextField(
              controller: ctl,
              focusNode: focus,
              textAlign: TextAlign.right,
              decoration: InputDecoration(hintText: hint, filled: false, border: InputBorder.none, focusedBorder: InputBorder.none, isDense: true),
            ),
            optionsViewBuilder: (ctx, onSelected, options) => Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 4,
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
                  child: ListView(padding: EdgeInsets.zero, shrinkWrap: true, children: [
                    for (final o in options) ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
                  ]),
                ),
              ),
            ),
          );
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 78, child: Text(label, style: TextStyle(color: p.text2))),
        Expanded(child: field),
        ?trailing,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final remote = fr?.coverUrlLarge ?? fr?.coverUrl;
    Widget coverWidget;
    switch (cover) {
      case _CoverMode.keep:
        coverWidget = CoverImage.book(context, editing!);
      case _CoverMode.photo:
        coverWidget = CoverImage(title: title.text, file: File(photo!));
      case _CoverMode.remote:
        coverWidget = CoverImage(title: title.text, url: remote);
      case _CoverMode.none:
        coverWidget = CoverImage(title: title.text.isEmpty ? 'Sem título' : title.text, author: authors.text.split(',').first);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(editing != null ? 'Editar livro' : 'Novo livro'),
        actions: [IconButton(onPressed: saving ? null : _save, icon: const Icon(Icons.check_rounded), tooltip: 'Salvar')],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 112,
            child: Stack(clipBehavior: Clip.none, children: [
              coverWidget,
              Positioned(
                left: 0,
                right: 0,
                bottom: -16,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(visualDensity: VisualDensity.compact, color: p.inkText, iconSize: 18, tooltip: 'Tirar foto da capa',
                          onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined)),
                      IconButton(visualDensity: VisualDensity.compact, color: p.inkText, iconSize: 18, tooltip: 'Escolher imagem',
                          onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.image_outlined)),
                      if (cover != _CoverMode.none)
                        IconButton(visualDensity: VisualDensity.compact, color: p.inkText, iconSize: 18, tooltip: 'Remover capa',
                            onPressed: () => setState(() => cover = _CoverMode.none), icon: const Icon(Icons.delete_outline_rounded)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(children: [
                TextField(
                  controller: title,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: 'Título *', filled: false, border: InputBorder.none, focusedBorder: InputBorder.none),
                ),
                Divider(color: p.line),
                TextField(
                  controller: authors,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: p.text2),
                  decoration: const InputDecoration(hintText: 'Autor(es), separados por vírgula', filled: false, border: InputBorder.none, focusedBorder: InputBorder.none),
                ),
                Divider(color: p.line),
                TextField(
                  controller: subtitle,
                  style: TextStyle(color: p.text2, fontSize: 13),
                  decoration: const InputDecoration(hintText: 'Subtítulo (opcional)', filled: false, border: InputBorder.none, focusedBorder: InputBorder.none),
                ),
                if (photo != null && remote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(spacing: 6, children: [
                      Pill(small: true, label: 'Capa da internet', selected: cover == _CoverMode.remote, onTap: () => setState(() => cover = _CoverMode.remote)),
                      Pill(small: true, label: 'Minha foto', selected: cover == _CoverMode.photo, onTap: () => setState(() => cover = _CoverMode.photo)),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 26),
        _row('Editora', publisher),
        _row('Ano', year, kb: TextInputType.number),
        _row('Páginas', pages, kb: TextInputType.number),
        _row('Gênero', categories, hint: 'Ex.: Fantasia', suggestions: _genres),
        _row('ISBN', isbn,
            kb: TextInputType.number,
            trailing: asIsbn(isbn.text) == null
                ? null
                : TextButton.icon(
                    style: TextButton.styleFrom(backgroundColor: p.ink, foregroundColor: p.inkText, visualDensity: VisualDensity.compact),
                    onPressed: looking ? null : _fillFromIsbn,
                    icon: const Icon(Icons.search_rounded, size: 15),
                    label: Text(looking ? '…' : 'Completar'),
                  )),
        const SizedBox(height: 20),
        const Text('Status da leitura', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Segmented<ReadingStatus>(
          values: ReadingStatus.values,
          value: status,
          label: (s) => s.label,
          onChanged: (s) => setState(() {
            status = s;
            if (s == ReadingStatus.reading) startedAt ??= todayIso();
            if (s == ReadingStatus.read) finishedAt ??= todayIso();
          }),
        ),
        if (status != ReadingStatus.want) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateTile('Comecei em', startedAt, () => _date(true))),
            if (status == ReadingStatus.read || finishedAt != null) ...[
              const SizedBox(width: 10),
              Expanded(child: _dateTile('Terminei em', finishedAt, () => _date(false))),
            ],
            if (status == ReadingStatus.reading || status == ReadingStatus.abandoned) ...[
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: pagesRead, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Páginas lidas')),
              ),
            ],
          ]),
        ],
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Avaliação', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Stars(value: rating, size: 30, onChanged: (v) => setState(() => rating = v)),
            ]),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: favorite ? const Color(0x24E2445C) : p.surface2,
              foregroundColor: favorite ? const Color(0xFFE2445C) : p.text,
            ),
            onPressed: () => setState(() => favorite = !favorite),
            icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19),
            label: const Text('Favorito'),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Anotações (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: notes, minLines: 3, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Escreva algo sobre este livro…')),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Sinopse e link digital', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              childrenPadding: const EdgeInsets.only(bottom: 14),
              children: [
                TextField(controller: description, minLines: 4, maxLines: 12, decoration: const InputDecoration(labelText: 'Sinopse')),
                const SizedBox(height: 10),
                TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link para uma versão digital legal (opcional)', hintText: 'https://…')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(saving ? 'Salvando…' : editing != null ? 'Salvar alterações' : 'Salvar na biblioteca'),
        ),
      ]),
    );
  }

  Widget _dateTile(String label, String? iso, VoidCallback onTap) {
    final p = context.pal;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.text2)),
          Text(iso == null ? '—' : fmtDate(iso), style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
