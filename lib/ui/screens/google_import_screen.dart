import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/books_api.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_parts.dart';
import '../widgets/common.dart';

/// Importa as estantes públicas do Google Livros para a estante do app.
class GoogleImportScreen extends StatefulWidget {
  const GoogleImportScreen({super.key});
  @override
  State<GoogleImportScreen> createState() => _GoogleImportScreenState();
}

class _GoogleImportScreenState extends State<GoogleImportScreen> {
  final link = TextEditingController();
  String? uid, error;
  List<GoogleShelf>? shelves;
  final selected = <int>{};
  bool loading = false, importing = false;
  String progress = '';
  int? done;

  AppState get app => context.read<AppState>();

  Future<void> loadShelves() async {
    final id = BooksApi.googleUserId(link.text);
    FocusScope.of(context).unfocus();
    if (id == null) {
      setState(() => error = 'Não achei o código da sua biblioteca nesse link. Ele tem “uid=” seguido de números.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      shelves = null;
    });
    try {
      final all = await app.api.googleShelves(id);
      final useful = all.where((s) => s.count > 0 && s.id != 6 && s.id != 9 && s.id != 8).toList();
      setState(() {
        uid = id;
        shelves = useful;
        selected
          ..clear()
          ..addAll(useful.where((s) => const {0, 2, 3, 4}.contains(s.id) || s.id >= 1000).map((s) => s.id));
        if (useful.isEmpty) {
          error = 'Nenhuma estante pública com livros. No Google Livros, deixe as estantes como “Públicas” e tente de novo.';
        }
      });
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> runImport() async {
    setState(() {
      importing = true;
      progress = 'Lendo as estantes…';
    });
    // Junta os livros de todas as estantes escolhidas; o mesmo livro pode estar em várias.
    final byKey = <String, (SearchResult, ReadingStatus, bool)>{};
    try {
      for (final s in shelves!.where((s) => selected.contains(s.id))) {
        setState(() => progress = 'Lendo “${s.label}”…');
        for (final r in await app.api.googleShelfVolumes(uid!, s.id)) {
          final prev = byKey[r.key];
          var status = prev?.$2 ?? ReadingStatus.want;
          if (s.id == 4) status = ReadingStatus.read;
          if (s.id == 3 && status != ReadingStatus.read) status = ReadingStatus.reading;
          final fav = (prev?.$3 ?? false) || s.id == 0;
          byKey[r.key] = (r, status, fav);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => importing = false);
        toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }
    var added = 0, skipped = 0, i = 0;
    for (final (r, status, fav) in byKey.values) {
      i++;
      if (!mounted) return;
      setState(() => progress = 'Adicionando $i de ${byKey.length}: ${r.title}');
      if (app.findExisting(key: r.key, isbn13: r.isbn13, title: r.title, authors: r.authors) != null) {
        skipped++;
        continue;
      }
      try {
        await app.addFromResult(r, status: status, favorite: fav);
        added++;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      importing = false;
      done = added;
    });
    toast(context, '$added livros importados${skipped > 0 ? ' ($skipped já estavam na estante)' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 11, backgroundColor: p.ink, child: Text('$n', style: TextStyle(fontSize: 12, color: p.inkText, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Importar do Google Livros')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Como pegar o link da sua biblioteca', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            step(1, 'Toque no botão abaixo para abrir o Google Livros e entre com sua conta Google.'),
            step(2, 'Abra “Minha biblioteca”. Em cada estante que quiser trazer, deixe a visibilidade como “Pública”.'),
            step(3, 'Copie o endereço da página (ele tem “uid=” e um número) e cole aqui embaixo.'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => openUrl(context, 'https://books.google.com/books?op=library'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir minha biblioteca no Google Livros'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: link,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'Cole o link (…uid=123456…)',
            prefixIcon: const Icon(Icons.link_rounded),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: loading ? null : loadShelves),
          ),
          onSubmitted: (_) => loadShelves(),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: loading || importing ? null : loadShelves, child: Text(loading ? 'Procurando estantes…' : 'Buscar minhas estantes')),
        if (error != null)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Text(error!, style: TextStyle(color: p.danger, fontSize: 13.5)),
          ),
        if (shelves != null && shelves!.isNotEmpty) ...[
          const SectionHeader('Estantes encontradas'),
          for (final s in shelves!)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(s.id),
              onChanged: importing ? null : (v) => setState(() => v == true ? selected.add(s.id) : selected.remove(s.id)),
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${s.count} ${s.count == 1 ? 'livro' : 'livros'} · ${switch (s.id) {
                0 => 'entram como favoritos',
                3 => 'entram como “Lendo”',
                4 => 'entram como “Concluído”',
                _ => 'entram como “Quero ler”',
              }}'),
            ),
          const SizedBox(height: 12),
          if (importing) ...[
            LinearProgressIndicator(color: p.ink, backgroundColor: p.surface3),
            const SizedBox(height: 8),
            Text(progress, style: TextStyle(color: p.text2, fontSize: 13)),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: selected.isEmpty ? null : runImport,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Importar para minha estante'),
            ),
          if (done != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton(onPressed: () => Navigator.pop(context), child: Text('Pronto — $done livros novos. Ver minha estante')),
            ),
        ],
      ]),
    );
  }
}
