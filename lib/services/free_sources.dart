// Acervos públicos de leitura gratuita e legal (domínio público ou licença livre).
// Nenhum exige chave nem login.
//  - Gutendex: API do Project Gutenberg (mais de 70 mil e-books, EPUB/HTML).
//  - Internet Archive: textos digitalizados; filtramos só os de acesso livre.
//  - Wikisource em português: clássicos da literatura em língua portuguesa.
//  - LibriVox: audiolivros de domínio público, lidos por voluntários.

import '../models/book.dart';
import 'text_utils.dart';

// ------------------------------------------------------------ Gutenberg
Uri gutendexUri(String q) => Uri.https('gutendex.com', '/books/', {'search': q});

/// "Assis, Machado de" -> "Machado de Assis"
String _flipName(String n) {
  final parts = n.split(', ');
  return parts.length == 2 ? '${parts[1]} ${parts[0]}' : n;
}

List<SearchResult> parseGutendex(dynamic json) {
  final out = <SearchResult>[];
  for (final raw in (json as Map)['results'] as List? ?? const []) {
    final b = Map<String, dynamic>.from(raw as Map);
    final id = b['id'];
    final formats = Map<String, dynamic>.from(b['formats'] as Map? ?? {});
    String? fmt(String prefix) => formats.entries.where((e) => e.key.startsWith(prefix)).map((e) => e.value as String).firstOrNull;
    final epub = fmt('application/epub');
    final html = fmt('text/html');
    out.add(SearchResult(
      key: 'gutenberg:$id',
      provider: BookSource.gutenberg,
      providerId: '$id',
      title: (b['title'] as String? ?? 'Sem título').split(RegExp(r'[:;]\s')).first,
      authors: [for (final a in (b['authors'] as List? ?? const [])) _flipName((a as Map)['name'] as String? ?? '')],
      categories: cleanCategories((b['bookshelves'] as List?)?.cast<String>().map((x) => x.replaceFirst('Browsing: ', '')).toList()),
      language: (b['languages'] as List?)?.cast<String>().firstOrNull,
      coverUrl: fmt('image/jpeg'),
      coverUrlLarge: fmt('image/jpeg'),
      freeDigital: true,
      links: [
        if (html != null) BookLink(LinkKind.read, 'Ler grátis no Project Gutenberg', html),
        if (epub != null) BookLink(LinkKind.read, 'Baixar EPUB grátis (Gutenberg)', epub),
        BookLink(LinkKind.info, 'Página no Project Gutenberg', 'https://www.gutenberg.org/ebooks/$id'),
      ],
    ));
  }
  return out;
}

// ------------------------------------------------------ Internet Archive
Uri archiveUri(String q) => Uri.https('archive.org', '/advancedsearch.php', {
      // Só textos de acesso livre: fora as coleções de empréstimo e as restritas.
      'q': '($q) AND mediatype:texts AND NOT collection:inlibrary AND NOT collection:printdisabled '
          'AND NOT access-restricted-item:true',
      'fl[]': ['identifier', 'title', 'creator', 'year', 'language', 'description'],
      'sort[]': 'downloads desc',
      'rows': '15',
      'output': 'json',
    });

String? _first(dynamic v) => v is List ? (v.isEmpty ? null : '${v.first}') : v?.toString();

List<SearchResult> parseArchive(dynamic json) {
  final docs = ((json as Map)['response'] as Map?)?['docs'] as List? ?? const [];
  return [
    for (final raw in docs)
      () {
        final d = Map<String, dynamic>.from(raw as Map);
        final id = d['identifier'] as String;
        final creators = d['creator'] is List ? (d['creator'] as List).map((e) => '$e').toList() : [if (d['creator'] != null) '${d['creator']}'];
        return SearchResult(
          key: 'archive:$id',
          provider: BookSource.archive,
          providerId: id,
          title: _first(d['title']) ?? id,
          authors: creators.map(_flipName).toList(),
          year: yearOf(d['year']),
          language: _first(d['language']),
          description: stripHtml(_first(d['description'])),
          coverUrl: 'https://archive.org/services/img/$id',
          coverUrlLarge: 'https://archive.org/services/img/$id',
          freeDigital: true,
          links: [BookLink(LinkKind.read, 'Ler grátis no Internet Archive', 'https://archive.org/details/$id')],
        );
      }(),
  ];
}

// ---------------------------------------------------------- Wikisource
Uri wikisourceUri(String q) => Uri.https('pt.wikisource.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': q,
      'srnamespace': '0',
      'srlimit': '10',
      'format': 'json',
    });

List<SearchResult> parseWikisource(dynamic json) {
  final items = ((json as Map)['query'] as Map?)?['search'] as List? ?? const [];
  return [
    for (final raw in items)
      () {
        final title = (raw as Map)['title'] as String;
        // Capítulos aparecem como "Livro/Capítulo": fica o nome da obra.
        final work = title.split('/').first;
        return SearchResult(
          key: 'wikisource:$work',
          provider: BookSource.wikisource,
          providerId: work,
          title: work,
          language: 'pt',
          freeDigital: true,
          links: [BookLink(LinkKind.read, 'Ler grátis no Wikisource', 'https://pt.wikisource.org/wiki/${Uri.encodeComponent(work.replaceAll(' ', '_'))}')],
        );
      }(),
  ].fold<List<SearchResult>>([], (acc, r) => acc.any((x) => x.key == r.key) ? acc : (acc..add(r)));
}

// ------------------------------------------------------------- LibriVox
Uri librivoxUri(String q) => Uri.https('librivox.org', '/api/feed/audiobooks/', {
      'title': q,
      'format': 'json',
      'limit': '10',
      'extended': '1',
    });

List<SearchResult> parseLibrivox(dynamic json) {
  if (json is! Map || json['books'] is! List) return const [];
  return [
    for (final raw in json['books'] as List)
      () {
        final b = Map<String, dynamic>.from(raw as Map);
        final authors = [
          for (final a in (b['authors'] as List? ?? const []))
            '${(a as Map)['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim(),
        ];
        final url = (b['url_librivox'] as String?) ?? 'https://librivox.org';
        return SearchResult(
          key: 'librivox:${b['id']}',
          provider: BookSource.librivox,
          providerId: '${b['id']}',
          title: '${b['title'] ?? 'Sem título'}',
          authors: authors,
          year: yearOf(b['copyright_year']),
          language: b['language'] as String?,
          description: stripHtml(b['description'] as String?),
          categories: const ['Audiolivro'],
          freeDigital: true,
          links: [
            BookLink(LinkKind.read, 'Ouvir grátis no LibriVox (audiolivro)', url),
            if (b['url_zip_file'] != null) BookLink(LinkKind.read, 'Baixar audiolivro (MP3)', '${b['url_zip_file']}'),
          ],
        );
      }(),
  ];
}
