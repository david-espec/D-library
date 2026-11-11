import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';
import 'free_sources.dart' as free;
import 'isbn.dart';
import 'text_utils.dart';

enum SearchField {
  all('Todos', 'Título, autor, ISBN…'),
  title('Título', 'Ex.: Dom Casmurro'),
  author('Autores', 'Ex.: Clarice Lispector'),
  isbn('ISBN', 'Ex.: 9788535914849'),
  publisher('Editora', 'Ex.: Companhia das Letras'),
  subject('Categorias', 'Ex.: fantasia, história'),
  free('Grátis', 'Livros para ler de graça (domínio público)');

  const SearchField(this.label, this.hint);
  final String label;
  final String hint;
}

class RateLimitError implements Exception {
  @override
  String toString() => 'Limite de consultas do Google atingido. Tente de novo em alguns minutos.';
}

/// Estante do Google Livros. IDs fixos do Google: 0 Favoritos, 2 Para ler,
/// 3 Lendo agora, 4 Lidos; as demais são compras, histórico etc.
class GoogleShelf {
  final int id;
  final String title;
  final int count;
  const GoogleShelf(this.id, this.title, this.count);

  String get label => const {
        0: 'Favoritos',
        1: 'Comprados',
        2: 'Para ler',
        3: 'Lendo agora',
        4: 'Lidos',
        5: 'Avaliados',
        6: 'Vistos recentemente',
        7: 'Meus e-books',
      }[id] ?? title;
}

class SearchOutcome {
  final List<SearchResult> results;
  final List<String> failed;
  const SearchOutcome(this.results, this.failed);
}

/// Links de busca em livrarias e sebos, a partir do ISBN ou do título.
List<BookLink> shopLinks({required String title, List<String> authors = const [], String? isbn13, String? isbn10}) {
  final isbn = isbn13 ?? isbn10;
  final text = [title, if (authors.isNotEmpty) authors.first].join(' ');
  final q = Uri.encodeQueryComponent(isbn ?? text);
  final qt = Uri.encodeQueryComponent(text);
  return [
    BookLink(LinkKind.buy, 'Amazon', 'https://www.amazon.com.br/s?k=$q&i=stripbooks'),
    BookLink(LinkKind.buy, 'Estante Virtual (sebos)', 'https://www.estantevirtual.com.br/busca?q=$qt'),
    BookLink(LinkKind.info, 'Pesquisar na web', 'https://www.google.com/search?tbm=bks&q=$q'),
  ];
}

/// Cliente das APIs públicas (Google Books e Open Library).
class BooksApi {
  BooksApi({http.Client? client, this.apiKey = ''}) : _client = client ?? http.Client();

  final http.Client _client;
  String apiKey;

  /// Resultados já vistos, para abrir o detalhe sem nova consulta.
  static final Map<String, SearchResult> cache = {};

  static const _timeout = Duration(seconds: 15);

  // ------------------------------------------------------------------ Google
  static String _https(String u) => u.replaceFirst(RegExp(r'^http:'), 'https:');

  static SearchResult fromGoogle(Map<String, dynamic> v) {
    final i = Map<String, dynamic>.from(v['volumeInfo'] as Map? ?? {});
    final ids = (i['industryIdentifiers'] as List? ?? const []).cast<Map>();
    String? id(String t) => ids.where((x) => x['type'] == t).map((x) => x['identifier'] as String).firstOrNull;
    final a = Map<String, dynamic>.from(v['accessInfo'] as Map? ?? {});
    final sale = Map<String, dynamic>.from(v['saleInfo'] as Map? ?? {});
    final full = a['viewability'] == 'ALL_PAGES' || a['publicDomain'] == true;
    final links = <BookLink>[];
    if (full && a['webReaderLink'] != null) links.add(BookLink(LinkKind.read, 'Ler grátis no Google Books', _https(a['webReaderLink'])));
    final epub = a['epub'] as Map?, pdf = a['pdf'] as Map?;
    if (a['publicDomain'] == true && epub?['downloadLink'] != null) {
      links.add(BookLink(LinkKind.read, 'Baixar EPUB (domínio público)', _https(epub!['downloadLink'])));
    }
    if (a['publicDomain'] == true && pdf?['downloadLink'] != null) {
      links.add(BookLink(LinkKind.read, 'Baixar PDF (domínio público)', _https(pdf!['downloadLink'])));
    }
    if (!full && a['viewability'] == 'PARTIAL' && i['previewLink'] != null) {
      links.add(BookLink(LinkKind.preview, 'Prévia no Google Books', _https(i['previewLink'])));
    }
    if (sale['saleability'] == 'FOR_SALE' && sale['buyLink'] != null) {
      links.add(BookLink(LinkKind.buy, 'Comprar e-book (Google Play)', _https(sale['buyLink'])));
    }
    final info = i['canonicalVolumeLink'] ?? i['infoLink'];
    if (info != null) links.add(BookLink(LinkKind.info, 'Ficha no Google Books', _https(info)));

    final img = Map<String, dynamic>.from(i['imageLinks'] as Map? ?? {});
    String? cover = (img['thumbnail'] ?? img['smallThumbnail']) as String?;
    String? large;
    if (cover != null) {
      cover = _https(cover).replaceAll('&edge=curl', '');
      final big = (img['large'] ?? img['medium'] ?? img['small']) as String?;
      large = big != null ? _https(big) : '${cover.replaceAll(RegExp(r'&zoom=\d'), '')}&fife=w600-h900';
    }
    final gid = v['id'] as String;
    return SearchResult(
      key: 'google:$gid',
      provider: BookSource.google,
      providerId: gid,
      title: i['title'] as String? ?? 'Sem título',
      subtitle: i['subtitle'] as String?,
      authors: List<String>.from(i['authors'] as List? ?? const []),
      publisher: i['publisher'] as String?,
      year: yearOf(i['publishedDate']),
      description: stripHtml(i['description'] as String?),
      categories: cleanCategories(List<String>.from(i['categories'] as List? ?? const [])),
      pageCount: (i['pageCount'] as num?)?.toInt() == 0 ? null : (i['pageCount'] as num?)?.toInt(),
      isbn13: id('ISBN_13'),
      isbn10: id('ISBN_10'),
      language: i['language'] as String?,
      links: links,
      coverUrl: cover,
      coverUrlLarge: large,
      rating: (i['averageRating'] as num?)?.toDouble(),
      ratingsCount: (i['ratingsCount'] as num?)?.toInt(),
      freeDigital: full,
    );
  }

  static String _googleQuery(String t, SearchField f) => switch (f) {
        SearchField.title => 'intitle:$t',
        SearchField.author => 'inauthor:$t',
        SearchField.isbn => 'isbn:${cleanIsbn(t)}',
        SearchField.publisher => 'inpublisher:$t',
        SearchField.subject => 'subject:$t',
        SearchField.all || SearchField.free => t,
      };

  Future<List<SearchResult>> searchGoogle(String text, SearchField field, {int max = 24}) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
      'q': _googleQuery(text.trim(), field),
      'maxResults': '$max',
      'printType': 'books',
      if (apiKey.isNotEmpty) 'key': apiKey,
    });
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode == 429) throw RateLimitError();
    if (res.statusCode != 200) throw Exception('Google Books: ${res.statusCode}');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [for (final v in (json['items'] as List? ?? const [])) fromGoogle(Map<String, dynamic>.from(v as Map))];
  }

  Future<SearchResult> googleVolume(String id) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes/$id', {if (apiKey.isNotEmpty) 'key': apiKey});
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Google Books: ${res.statusCode}');
    return fromGoogle(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  // ------------------------------------------------------------ Open Library
  static const _olFields = 'key,title,subtitle,author_name,first_publish_year,publisher,isbn,cover_i,'
      'number_of_pages_median,subject,language,ebook_access,ia,ratings_average,ratings_count';

  static String olCover(int id, String size) => 'https://covers.openlibrary.org/b/id/$id-$size.jpg';

  static String? _pickIsbn(List<String> isbns, String? wanted) {
    if (wanted != null && isbns.contains(wanted)) return wanted;
    final t = isbns.where(isValidIsbn13).toList();
    final br = t.where((i) => i.startsWith('97885') || i.startsWith('97865'));
    if (br.isNotEmpty) return br.first;
    if (t.isNotEmpty) return t.first;
    final ten = isbns.where(isValidIsbn10);
    return ten.isNotEmpty ? isbn10to13(ten.first) : null;
  }

  static SearchResult fromOpenLibrary(Map<String, dynamic> d, {String? wantedIsbn}) {
    final key = d['key'] as String;
    final ia = (d['ia'] as List?)?.cast<String>();
    final access = d['ebook_access'] as String?;
    final links = <BookLink>[
      if (access == 'public' && ia != null && ia.isNotEmpty)
        BookLink(LinkKind.read, 'Ler grátis no Internet Archive', 'https://archive.org/details/${ia.first}')
      else if (access == 'borrowable')
        BookLink(LinkKind.read, 'Emprestar grátis no Open Library', 'https://openlibrary.org$key'),
      BookLink(LinkKind.info, 'Ficha no Open Library', 'https://openlibrary.org$key'),
    ];
    final cover = (d['cover_i'] as num?)?.toInt();
    final r = (d['ratings_average'] as num?)?.toDouble();
    return SearchResult(
      key: 'openlibrary:$key',
      provider: BookSource.openlibrary,
      providerId: key,
      title: d['title'] as String? ?? 'Sem título',
      subtitle: d['subtitle'] as String?,
      authors: List<String>.from(d['author_name'] as List? ?? const []),
      publisher: (d['publisher'] as List?)?.cast<String>().firstOrNull,
      year: yearOf(d['first_publish_year']),
      categories: cleanCategories((d['subject'] as List?)?.cast<String>().take(6).toList()),
      pageCount: (d['number_of_pages_median'] as num?)?.toInt(),
      isbn13: _pickIsbn(List<String>.from(d['isbn'] as List? ?? const []), wantedIsbn),
      language: (d['language'] as List?)?.cast<String>().firstOrNull,
      links: links,
      rating: r == null ? null : (r * 10).round() / 10,
      ratingsCount: (d['ratings_count'] as num?)?.toInt(),
      freeDigital: access == 'public' || access == 'borrowable',
      coverUrl: cover != null ? olCover(cover, 'M') : null,
      coverUrlLarge: cover != null ? olCover(cover, 'L') : null,
    );
  }

  Future<List<SearchResult>> searchOpenLibrary(String text, SearchField field, {int max = 20}) async {
    final t = text.trim();
    final isbn = field == SearchField.isbn ? cleanIsbn(t) : null;
    final param = switch (field) {
      SearchField.all || SearchField.free => 'q',
      SearchField.title => 'title',
      SearchField.author => 'author',
      SearchField.isbn => 'isbn',
      SearchField.publisher => 'publisher',
      SearchField.subject => 'subject',
    };
    final uri = Uri.https('openlibrary.org', '/search.json', {param: isbn ?? t, 'fields': _olFields, 'limit': '$max'});
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Open Library: ${res.statusCode}');
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [for (final d in (json['docs'] as List? ?? const [])) fromOpenLibrary(Map<String, dynamic>.from(d as Map), wantedIsbn: isbn)];
  }

  Future<({String? description, List<String> subjects})> openLibraryWork(String workKey) async {
    final res = await _client.get(Uri.parse('https://openlibrary.org$workKey.json')).timeout(_timeout);
    if (res.statusCode != 200) throw Exception('Open Library: ${res.statusCode}');
    final w = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final d = w['description'];
    final desc = d is String ? d : (d is Map ? d['value'] as String? : null);
    return (
      description: desc?.replaceAll('\r\n', '\n').replaceAll(RegExp(r'\(\[source\]\[\d+\]\)|\[\d+\]: \S+'), '').trim(),
      subjects: List<String>.from(w['subjects'] as List? ?? const []),
    );
  }

  // ------------------------------------------------------------------ Juntos
  static String _dedupeKey(SearchResult r) {
    if (r.isbn13 != null) return r.isbn13!;
    final last = r.authors.isNotEmpty ? r.authors.first.split(' ').last : '';
    return '${norm(r.title)}|${norm(last)}';
  }

  /// Pesquisa nas duas fontes ao mesmo tempo, intercala e junta duplicatas.
  Future<SearchOutcome> search(String text, SearchField field) async {
    if (field == SearchField.free) return searchFree(text);
    var f = field;
    if (f == SearchField.all && asIsbn(text) != null) f = SearchField.isbn;
    final q = f == SearchField.isbn ? (asIsbn(text) ?? text) : text;

    final failed = <String>[];
    Future<List<SearchResult>> guard(Future<List<SearchResult>> fut, String name) =>
        fut.catchError((Object e) {
          failed.add(e is RateLimitError ? '$name (limite de consultas)' : name);
          return <SearchResult>[];
        });
    final both = await Future.wait([guard(searchGoogle(q, f), 'Google Books'), guard(searchOpenLibrary(q, f), 'Open Library')]);
    final g = both[0], o = both[1];

    final interleaved = <SearchResult>[];
    for (var i = 0; i < (g.length > o.length ? g.length : o.length); i++) {
      if (i < g.length) interleaved.add(g[i]);
      if (i < o.length) interleaved.add(o[i]);
    }
    final byKey = <String, SearchResult>{};
    for (final r in interleaved) {
      final k = _dedupeKey(r);
      byKey[k] = byKey.containsKey(k) ? byKey[k]!.mergeWith(r) : r;
    }
    // Com capa e ISBN primeiro, mantendo a ordem de relevância.
    final list = byKey.values.toList();
    final scored = [for (var i = 0; i < list.length; i++) (list[i], i - (list[i].coverUrl != null ? 6 : 0) - (list[i].isbn13 != null ? 2 : 0))];
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    final results = [for (final s in scored) s.$1];
    for (final r in results) {
      cache[r.key] = r;
    }
    if (results.isEmpty && failed.length == 2) {
      throw Exception('Não foi possível consultar as fontes. Verifique a internet.');
    }
    return SearchOutcome(results, failed);
  }

  /// Detalhe completo: sinopse e, se faltar algo, completa com a outra fonte.
  Future<SearchResult> details(SearchResult base) async {
    var r = base;
    try {
      if (r.provider == BookSource.google) {
        r = (await googleVolume(r.providerId)).mergeWith(r);
      } else if (r.provider != BookSource.openlibrary) {
        // Fontes gratuitas: completa capa/sinopse pelo Google Books, se achar.
        final g = await searchGoogle('${r.title} ${r.authors.firstOrNull ?? ''}', SearchField.all, max: 3);
        final same = g.where((x) => norm(x.title) == norm(r.title)).firstOrNull;
        if (same != null) r = r.mergeWith(same);
      } else {
        final w = await openLibraryWork(r.providerId);
        r = r.copyWith(
          description: r.description ?? w.description,
          categories: r.categories.isNotEmpty ? r.categories : cleanCategories(w.subjects),
        );
      }
    } catch (_) {}
    if (r.description == null && r.isbn13 != null) {
      try {
        final other = r.provider != BookSource.openlibrary
            ? await searchOpenLibrary(r.isbn13!, SearchField.isbn, max: 1)
            : await searchGoogle(r.isbn13!, SearchField.isbn, max: 1);
        if (other.isNotEmpty) {
          var extra = other.first;
          if (extra.provider == BookSource.openlibrary) {
            final w = await openLibraryWork(extra.providerId).catchError((_) => (description: null, subjects: <String>[]));
            if (w.description != null) extra = extra.copyWith(description: w.description);
          }
          r = r.mergeWith(extra);
        }
      } catch (_) {}
    }
    cache[r.key] = r;
    return r;
  }

  // ------------------------------------------------------- Google Livros
  /// Extrai o ID de usuário do Google Livros de um link (…uid=123…) ou do próprio número.
  static String? googleUserId(String text) {
    final t = text.trim();
    final m = RegExp(r'uid=(\d{5,})').firstMatch(t) ?? RegExp(r'users/(\d{5,})').firstMatch(t);
    if (m != null) return m.group(1);
    return RegExp(r'^\d{5,}$').hasMatch(t) ? t : null;
  }

  /// Estantes públicas de um usuário do Google Livros.
  Future<List<GoogleShelf>> googleShelves(String uid) async {
    final uri = Uri.https('www.googleapis.com', '/books/v1/users/$uid/bookshelves', {if (apiKey.isNotEmpty) 'key': apiKey});
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode == 429) throw RateLimitError();
    if (res.statusCode == 404 || res.statusCode == 400) throw Exception('Biblioteca não encontrada. Confira o link.');
    if (res.statusCode != 200) throw Exception('Google Livros: ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final it in (j['items'] as List? ?? const []))
        GoogleShelf(
          (it['id'] as num).toInt(),
          (it['title'] as String?) ?? 'Estante',
          (it['volumeCount'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// Todos os livros de uma estante pública (paginado de 40 em 40).
  Future<List<SearchResult>> googleShelfVolumes(String uid, int shelf) async {
    final out = <SearchResult>[];
    for (var start = 0; start < 2000; start += 40) {
      final uri = Uri.https('www.googleapis.com', '/books/v1/users/$uid/bookshelves/$shelf/volumes', {
        'startIndex': '$start',
        'maxResults': '40',
        if (apiKey.isNotEmpty) 'key': apiKey,
      });
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode == 429) throw RateLimitError();
      if (res.statusCode != 200) throw Exception('Google Livros: ${res.statusCode}');
      final items = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['items'] as List? ?? const [];
      out.addAll([for (final v in items) fromGoogle(Map<String, dynamic>.from(v as Map))]);
      if (items.length < 40) break;
    }
    return out;
  }

  // ----------------------------------------------- Fontes gratuitas legais
  Future<List<SearchResult>> _get(Uri uri, List<SearchResult> Function(dynamic json) parse) async {
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) throw Exception('${uri.host}: ${res.statusCode}');
    return parse(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<List<SearchResult>> gutenberg(String q) => _get(free.gutendexUri(q), free.parseGutendex);
  Future<List<SearchResult>> archive(String q) => _get(free.archiveUri(q), free.parseArchive);
  Future<List<SearchResult>> wikisource(String q) => _get(free.wikisourceUri(q), free.parseWikisource);
  Future<List<SearchResult>> librivox(String q) => _get(free.librivoxUri(q), free.parseLibrivox);

  /// Pesquisa só em acervos de leitura gratuita e legal.
  Future<SearchOutcome> searchFree(String text) async {
    final q = text.trim();
    final failed = <String>[];
    Future<List<SearchResult>> guard(Future<List<SearchResult>> f, String name) =>
        f.catchError((Object _) {
          failed.add(name);
          return <SearchResult>[];
        });
    final lists = await Future.wait([
      guard(gutenberg(q), 'Project Gutenberg'),
      guard(wikisource(q), 'Wikisource'),
      guard(archive(q), 'Internet Archive'),
      guard(librivox(q), 'LibriVox'),
    ]);
    final out = <SearchResult>[];
    final seen = <String>{};
    final maxLen = lists.fold<int>(0, (m, l) => l.length > m ? l.length : m);
    for (var i = 0; i < maxLen; i++) {
      for (final l in lists) {
        if (i >= l.length) continue;
        final r = l[i];
        // Mesmo título/autor em fontes diferentes: mantém todos os links num só.
        final k = '${norm(r.title)}|${norm(r.authors.firstOrNull?.split(' ').last)}|${r.provider == BookSource.librivox}';
        if (seen.add(k)) {
          out.add(r);
        } else {
          final j = out.indexWhere((x) => '${norm(x.title)}|${norm(x.authors.firstOrNull?.split(' ').last)}|${x.provider == BookSource.librivox}' == k);
          if (j >= 0) out[j] = out[j].mergeWith(r);
        }
      }
    }
    for (final r in out) {
      cache[r.key] = r;
    }
    if (out.isEmpty && failed.length == lists.length) throw Exception('Não foi possível consultar os acervos gratuitos. Verifique a internet.');
    return SearchOutcome(out, failed);
  }

  /// Versões gratuitas de um livro específico (para mostrar no detalhe).
  Future<List<BookLink>> freeEditions(String title, List<String> authors) async {
    final author = authors.firstOrNull ?? '';
    final q = '$title ${author.split(' ').last}'.trim();
    final outcome = await searchFree(q).catchError((Object _) => const SearchOutcome([], []));
    final t = norm(title).split(' ').where((w) => w.length > 2).toSet();
    final links = <BookLink>[];
    for (final r in outcome.results) {
      final rt = norm(r.title).split(' ').where((w) => w.length > 2).toSet();
      // Exige que as palavras do título batam (evita livros só parecidos).
      if (t.isEmpty || rt.isEmpty || t.intersection(rt).length < (t.length < 2 ? 1 : (t.length * .6).ceil())) continue;
      if (author.isNotEmpty && r.authors.isNotEmpty) {
        final last = norm(author.split(' ').last);
        if (!r.authors.any((a) => norm(a).contains(last))) continue;
      }
      links.addAll(r.links.where((l) => l.kind == LinkKind.read));
    }
    return mergeLinks([links]).take(8).toList();
  }

  Future<List<SearchResult>> lookupIsbn(String isbn) async => (await search(isbn, SearchField.isbn)).results;

  /// Baixa a capa (para guardar no aparelho). null se não houver imagem útil.
  Future<List<int>?> downloadImage(List<String?> urls) async {
    for (final u in urls) {
      if (u == null) continue;
      try {
        final res = await _client.get(Uri.parse(u)).timeout(_timeout);
        final type = res.headers['content-type'] ?? '';
        // Os "imagem indisponível" costumam ser minúsculos.
        if (res.statusCode == 200 && type.startsWith('image/') && res.bodyBytes.length > 1500) return res.bodyBytes;
      } catch (_) {}
    }
    return null;
  }
}
