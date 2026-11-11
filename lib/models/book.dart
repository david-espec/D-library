import 'dart:convert';

/// Situação de leitura de um livro da estante.
enum ReadingStatus {
  want('Quero ler'),
  reading('Lendo'),
  read('Concluído'),
  abandoned('Abandonado');

  const ReadingStatus(this.label);
  final String label;

  static ReadingStatus parse(String? s) =>
      ReadingStatus.values.firstWhere((e) => e.name == s, orElse: () => ReadingStatus.want);
}

enum LinkKind { read, preview, buy, info }

/// Link externo: leitura legal gratuita, prévia, compra ou ficha.
class BookLink {
  final LinkKind kind;
  final String label;
  final String url;
  const BookLink(this.kind, this.label, this.url);

  Map<String, dynamic> toJson() => {'kind': kind.name, 'label': label, 'url': url};
  factory BookLink.fromJson(Map<String, dynamic> j) => BookLink(
        LinkKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => LinkKind.info),
        j['label'] as String? ?? '',
        j['url'] as String? ?? '',
      );
}

/// Junta links sem repetir URL; leitura gratuita primeiro.
List<BookLink> mergeLinks(List<List<BookLink>> lists) {
  final seen = <String>{};
  final out = <BookLink>[];
  for (final l in lists.expand((e) => e)) {
    if (seen.add(l.url)) out.add(l);
  }
  out.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return out;
}

enum BookSource {
  google('Google Books'),
  openlibrary('Open Library'),
  gutenberg('Project Gutenberg'),
  archive('Internet Archive'),
  wikisource('Wikisource'),
  librivox('LibriVox');

  const BookSource(this.label);
  final String label;
}

/// Livro encontrado numa API pública.
class SearchResult {
  final String key;
  final BookSource provider;
  final String providerId;
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? publisher;
  final String? year;
  final String? description;
  final List<String> categories;
  final int? pageCount;
  final String? isbn13;
  final String? isbn10;
  final String? language;
  final List<BookLink> links;
  final String? coverUrl;
  final String? coverUrlLarge;
  final double? rating;
  final int? ratingsCount;
  final bool freeDigital;

  const SearchResult({
    required this.key,
    required this.provider,
    required this.providerId,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.publisher,
    this.year,
    this.description,
    this.categories = const [],
    this.pageCount,
    this.isbn13,
    this.isbn10,
    this.language,
    this.links = const [],
    this.coverUrl,
    this.coverUrlLarge,
    this.rating,
    this.ratingsCount,
    this.freeDigital = false,
  });

  /// Completa este resultado com o que faltar, vindo de [b].
  SearchResult mergeWith(SearchResult b) => SearchResult(
        key: key,
        provider: provider,
        providerId: providerId,
        title: title,
        subtitle: subtitle ?? b.subtitle,
        authors: authors.isNotEmpty ? authors : b.authors,
        publisher: publisher ?? b.publisher,
        year: year ?? b.year,
        description: description ?? b.description,
        categories: categories.isNotEmpty ? categories : b.categories,
        pageCount: pageCount ?? b.pageCount,
        isbn13: isbn13 ?? b.isbn13,
        isbn10: isbn10 ?? b.isbn10,
        language: language ?? b.language,
        links: mergeLinks([links, b.links]),
        coverUrl: coverUrl ?? b.coverUrl,
        coverUrlLarge: coverUrlLarge ?? b.coverUrlLarge,
        rating: rating ?? b.rating,
        ratingsCount: ratingsCount ?? b.ratingsCount,
        freeDigital: freeDigital || b.freeDigital,
      );

  SearchResult copyWith({String? description, List<String>? categories}) => SearchResult(
        key: key, provider: provider, providerId: providerId, title: title, subtitle: subtitle,
        authors: authors, publisher: publisher, year: year, description: description ?? this.description,
        categories: categories ?? this.categories, pageCount: pageCount, isbn13: isbn13, isbn10: isbn10,
        language: language, links: links, coverUrl: coverUrl, coverUrlLarge: coverUrlLarge, rating: rating,
        ratingsCount: ratingsCount, freeDigital: freeDigital,
      );
}

class ProgressEntry {
  final String date; // yyyy-mm-dd
  final int pages; // total lido naquele dia
  const ProgressEntry(this.date, this.pages);
  Map<String, dynamic> toJson() => {'date': date, 'pages': pages};
  factory ProgressEntry.fromJson(Map<String, dynamic> j) => ProgressEntry(j['date'] as String, (j['pages'] as num).toInt());
}

/// Um livro da sua estante.
class Book {
  final String id;
  String title;
  String? subtitle;
  List<String> authors;
  String? publisher;
  String? year;
  String? description;
  List<String> categories;
  int? pageCount;
  String? isbn13;
  String? isbn10;
  String? language;
  List<BookLink> links;

  /// Arquivo da capa guardada no aparelho (nome dentro da pasta de capas).
  String? coverFile;

  /// Capa remota de reserva, caso o download falhe.
  String? coverUrl;

  /// 'google' | 'openlibrary' | 'manual'
  String origin;
  String? originId;
  ReadingStatus status;
  bool favorite;
  double rating;
  String notes;
  String? startedAt;
  String? finishedAt;
  int pagesRead;
  List<ProgressEntry> progress;
  final int createdAt;
  int updatedAt;

  Book({
    required this.id,
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.publisher,
    this.year,
    this.description,
    this.categories = const [],
    this.pageCount,
    this.isbn13,
    this.isbn10,
    this.language,
    this.links = const [],
    this.coverFile,
    this.coverUrl,
    this.origin = 'manual',
    this.originId,
    this.status = ReadingStatus.want,
    this.favorite = false,
    this.rating = 0,
    this.notes = '',
    this.startedAt,
    this.finishedAt,
    this.pagesRead = 0,
    this.progress = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isManual => origin == 'manual';
  String get firstAuthor => authors.isNotEmpty ? authors.first : '';
  double? get progressFraction => pageCount != null && pageCount! > 0 ? (pagesRead / pageCount!).clamp(0, 1).toDouble() : null;

  Book copy() => Book.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'authors': authors,
        'publisher': publisher,
        'year': year,
        'description': description,
        'categories': categories,
        'pageCount': pageCount,
        'isbn13': isbn13,
        'isbn10': isbn10,
        'language': language,
        'links': links.map((l) => l.toJson()).toList(),
        'coverFile': coverFile,
        'coverUrl': coverUrl,
        'origin': origin,
        'originId': originId,
        'status': status.name,
        'favorite': favorite,
        'rating': rating,
        'notes': notes,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'pagesRead': pagesRead,
        'progress': progress.map((p) => p.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Sem título',
        subtitle: j['subtitle'] as String?,
        authors: List<String>.from(j['authors'] as List? ?? const []),
        publisher: j['publisher'] as String?,
        year: j['year']?.toString(),
        description: j['description'] as String?,
        categories: List<String>.from(j['categories'] as List? ?? const []),
        pageCount: (j['pageCount'] as num?)?.toInt(),
        isbn13: j['isbn13'] as String?,
        isbn10: j['isbn10'] as String?,
        language: j['language'] as String?,
        links: [for (final l in (j['links'] as List? ?? const [])) BookLink.fromJson(Map<String, dynamic>.from(l as Map))],
        coverFile: j['coverFile'] as String?,
        coverUrl: j['coverUrl'] as String?,
        origin: j['origin'] as String? ?? 'manual',
        originId: j['originId'] as String?,
        status: ReadingStatus.parse(j['status'] as String?),
        favorite: j['favorite'] == true || j['favorite'] == 1,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        startedAt: j['startedAt'] as String?,
        finishedAt: j['finishedAt'] as String?,
        pagesRead: (j['pagesRead'] as num?)?.toInt() ?? 0,
        progress: [for (final p in (j['progress'] as List? ?? const [])) ProgressEntry.fromJson(Map<String, dynamic>.from(p as Map))],
        createdAt: (j['createdAt'] as num).toInt(),
        updatedAt: (j['updatedAt'] as num).toInt(),
      );

  String encode() => jsonEncode(toJson());
}
