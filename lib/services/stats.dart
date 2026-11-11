import '../models/book.dart';

/// Minutos por página usados na estimativa de tempo de leitura.
const minPerPage = 1.5;

class GenreStat {
  final String name;
  final int count;
  final double pct;
  const GenreStat(this.name, this.count, this.pct);
}

class Stats {
  final int total, readCount, readingCount, wantCount, abandonedCount, favorites, pagesRead, hours, readThisYear;
  final double avgRating, avgDays;
  final List<GenreStat> genres;
  final List<(String, int)> authors;
  final List<int> finishedByMonth, pagesByMonth;

  const Stats({
    required this.total,
    required this.readCount,
    required this.readingCount,
    required this.wantCount,
    required this.abandonedCount,
    required this.favorites,
    required this.pagesRead,
    required this.hours,
    required this.readThisYear,
    required this.avgRating,
    required this.avgDays,
    required this.genres,
    required this.authors,
    required this.finishedByMonth,
    required this.pagesByMonth,
  });

  factory Stats.of(List<Book> books, {int? year}) {
    final y = '${year ?? DateTime.now().year}';
    final read = books.where((b) => b.status == ReadingStatus.read).toList();
    final reading = books.where((b) => b.status == ReadingStatus.reading).toList();
    final rated = books.where((b) => b.rating > 0).toList();
    final pages = books.fold<int>(0, (s, b) => s + b.pagesRead);
    final thisYear = read.where((b) => b.finishedAt?.startsWith(y) ?? false).toList();

    final base = read.isNotEmpty || reading.isNotEmpty ? [...read, ...reading] : books;
    final gc = <String, int>{};
    for (final b in base) {
      final g = b.categories.isNotEmpty ? b.categories.first : 'Sem categoria';
      gc[g] = (gc[g] ?? 0) + 1;
    }
    final genres = gc.entries.map((e) => GenreStat(e.key, e.value, base.isEmpty ? 0 : e.value / base.length)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final ac = <String, int>{};
    for (final b in books) {
      if (b.authors.isNotEmpty) ac[b.authors.first] = (ac[b.authors.first] ?? 0) + 1;
    }
    final authors = ac.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));

    final fbm = List<int>.filled(12, 0);
    for (final b in thisYear) {
      fbm[int.parse(b.finishedAt!.substring(5, 7)) - 1]++;
    }
    final pbm = List<int>.filled(12, 0);
    for (final b in books) {
      var last = 0;
      final log = [...b.progress]..sort((a, c) => a.date.compareTo(c.date));
      for (final p in log) {
        final d = p.pages - last;
        last = p.pages;
        if (d > 0 && p.date.startsWith(y)) pbm[int.parse(p.date.substring(5, 7)) - 1] += d;
      }
    }

    final durations = <double>[];
    for (final b in read) {
      final s = DateTime.tryParse(b.startedAt ?? ''), f = DateTime.tryParse(b.finishedAt ?? '');
      if (s != null && f != null && !f.isBefore(s)) durations.add(f.difference(s).inDays + 1.0);
    }

    return Stats(
      total: books.length,
      readCount: read.length,
      readingCount: reading.length,
      wantCount: books.where((b) => b.status == ReadingStatus.want).length,
      abandonedCount: books.where((b) => b.status == ReadingStatus.abandoned).length,
      favorites: books.where((b) => b.favorite).length,
      pagesRead: pages,
      hours: (pages * minPerPage / 60).round(),
      readThisYear: thisYear.length,
      avgRating: rated.isEmpty ? 0 : rated.fold<double>(0, (s, b) => s + b.rating) / rated.length,
      avgDays: durations.isEmpty ? 0 : durations.reduce((a, b) => a + b) / durations.length,
      genres: genres,
      authors: authors.take(5).toList(),
      finishedByMonth: fbm,
      pagesByMonth: pbm,
    );
  }
}
