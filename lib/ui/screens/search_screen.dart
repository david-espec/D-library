import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/book.dart';
import '../../services/books_api.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'book_form_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final ctl = TextEditingController();
  final focusNode = FocusNode();
  SearchField field = SearchField.all;
  String query = '';
  List<SearchResult>? results;
  bool loading = false;
  String? error, warn;
  List<String> history = [];
  int _req = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString('search-history');
      if (raw != null && mounted) setState(() => history = List<String>.from(jsonDecode(raw) as List));
    });
  }

  void focus() => focusNode.requestFocus();

  void runQuery(String q) {
    ctl.text = q;
    _search();
  }

  Future<void> _saveHistory(String q) async {
    history = [q, ...history.where((h) => h != q)].take(8).toList();
    (await SharedPreferences.getInstance()).setString('search-history', jsonEncode(history));
  }

  Future<void> _search() async {
    final q = ctl.text.trim();
    if (q.isEmpty) return;
    focusNode.unfocus();
    final req = ++_req;
    setState(() {
      query = q;
      loading = true;
      error = null;
      warn = null;
    });
    _saveHistory(q);
    try {
      final out = await context.read<AppState>().api.search(q, field);
      if (req != _req || !mounted) return;
      setState(() {
        results = out.results;
        if (out.failed.isNotEmpty) warn = 'Sem resposta de: ${out.failed.join(', ')}. Mostrando o que foi encontrado.';
      });
    } catch (e) {
      if (req != _req || !mounted) return;
      setState(() {
        results = [];
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (req == _req && mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          sliver: SliverList.list(children: [
            TextField(
              controller: ctl,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: field.hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ListenableBuilder(
                  listenable: ctl,
                  builder: (_, _) => ctl.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(icon: const Icon(Icons.cancel_rounded, size: 20), onPressed: () {
                          ctl.clear();
                          focusNode.requestFocus();
                        }),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: SearchField.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = SearchField.values[i];
                return Pill(label: f.label, selected: f == field, onTap: () {
                  setState(() => field = f);
                  if (ctl.text.trim().isNotEmpty) {
                    _search();
                  } else {
                    focusNode.requestFocus();
                  }
                });
              },
            ),
          ),
        ),
        if (results == null && !loading)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            sliver: SliverList.list(children: [
              Material(
                color: p.ink,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.qr_code_scanner_rounded, color: p.inkText, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Está com o livro na mão?', style: TextStyle(color: p.inkText, fontWeight: FontWeight.w700)),
                          Text('Fotografe a capa ou o código de barras.', style: TextStyle(color: p.inkText.withValues(alpha: .7), fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
              if (history.isNotEmpty) ...[
                SectionHeader('Pesquisas recentes', action: 'Limpar', onAction: () async {
                  setState(() => history = []);
                  (await SharedPreferences.getInstance()).remove('search-history');
                }),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final h in history) Pill(label: h, onTap: () => runQuery(h))]),
              ],
              const SizedBox(height: 20),
              Text('Resultados do Google Books e do Open Library.', style: TextStyle(color: p.text2, fontSize: 13)),
            ]),
          ),
        if (loading)
          const SliverPadding(
            padding: EdgeInsets.all(18),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: .5, crossAxisSpacing: 14),
              delegate: SliverChildListDelegate.fixed([_Skeleton(), _Skeleton(), _Skeleton(), _Skeleton(), _Skeleton(), _Skeleton()]),
            ),
          ),
        if (!loading && (warn != null || error != null))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (error != null ? p.danger : p.star).withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error ?? warn!, style: TextStyle(fontSize: 13, color: error != null ? p.danger : p.text)),
              ),
            ),
          ),
        if (!loading && results != null && results!.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            sliver: SliverToBoxAdapter(child: Text('${results!.length} resultados para “$query”', style: TextStyle(color: p.text2, fontSize: 13))),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 170, childAspectRatio: .52, crossAxisSpacing: 14, mainAxisSpacing: 8),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ResultCard(
                  r: results![i],
                  owned: app.findExisting(key: results![i].key, isbn13: results![i].isbn13, title: results![i].title, authors: results![i].authors) != null,
                ),
                childCount: results!.length,
              ),
            ),
          ),
        ],
        if (!loading && results != null && results!.isEmpty && error == null)
          SliverPadding(
            padding: const EdgeInsets.all(40),
            sliver: SliverToBoxAdapter(
              child: Column(children: [
                Text('Nada encontrado para “$query”.', style: TextStyle(color: p.text2)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookFormScreen(
                      draft: field == SearchField.isbn
                          ? NewBook(title: '', isbn13: query)
                          : field == SearchField.author
                              ? NewBook(title: '', authors: [query])
                              : NewBook(title: query),
                    ),
                  )),
                  child: const Text('Cadastrar manualmente'),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    final c = context.pal.surface2;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(aspectRatio: 2 / 3, child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)))),
      const SizedBox(height: 8),
      Container(height: 12, width: 100, color: c),
      const SizedBox(height: 6),
      Container(height: 10, width: 60, color: c),
    ]);
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.r, this.owned = false});
  final SearchResult r;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        BooksApi.cache[r.key] = r;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(result: r)));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          CoverImage(title: r.title, author: r.authors.firstOrNull, url: r.coverUrl),
          if (owned)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(radius: 12, backgroundColor: p.green, child: const Icon(Icons.check_rounded, size: 15, color: Colors.white)),
            ),
          if (r.freeDigital)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: p.green, borderRadius: BorderRadius.circular(999)),
                child: const Text('Grátis', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.25)),
        Text('${r.authors.isEmpty ? 'Autor desconhecido' : r.authors.join(', ')}${r.year != null ? ' · ${r.year}' : ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: 12)),
      ]),
    );
  }
}
