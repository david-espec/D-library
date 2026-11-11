import 'package:d_libery/models/book.dart';
import 'package:d_libery/services/books_api.dart';
import 'package:d_libery/services/isbn.dart';
import 'package:d_libery/services/ocr.dart';
import 'package:d_libery/services/stats.dart';
import 'package:d_libery/services/text_utils.dart';
import 'package:d_libery/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

Book _book(String title, {ReadingStatus status = ReadingStatus.want, int pages = 0, int? total, String? finished, List<String> cats = const []}) => Book(
      id: title,
      title: title,
      status: status,
      pagesRead: pages,
      pageCount: total,
      finishedAt: finished,
      categories: cats,
      createdAt: 0,
      updatedAt: 0,
    );

void main() {
  test('ISBN: validação e conversão', () {
    expect(isValidIsbn13('9788525432186'), isTrue);
    expect(isValidIsbn13('9788525432187'), isFalse);
    expect(asIsbn('85-254-3218-X'), isNull);
    expect(asIsbn('0-306-40615-2'), '9780306406157');
    expect(isBookEan('9788525432186'), isTrue);
    expect(isBookEan('7891234567895'), isFalse);
  });

  test('texto: normalização, HTML e erros de OCR', () {
    expect(norm('História da Humanidade!'), 'historia da humanidade');
    expect(stripHtml('<p><b>Oi</b> &amp; tchau</p>'), 'Oi & tchau');
    expect(closeEnough('sapiens', 'saplens'), isTrue);
    expect(closeEnough('sapiens', 'homo'), isFalse);
    expect(translateCategory('Juvenile Fiction / General'), 'Infantojuvenil');
  });

  test('Google Books: converte volume e links legais', () {
    final r = BooksApi.fromGoogle({
      'id': 'x1',
      'volumeInfo': {
        'title': 'Dom Casmurro',
        'authors': ['Machado de Assis'],
        'publishedDate': '1899-01-01',
        'description': '<p>Bentinho e Capitu</p>',
        'industryIdentifiers': [{'type': 'ISBN_13', 'identifier': '9788572326972'}],
        'pageCount': 256,
        'categories': ['Fiction'],
        'imageLinks': {'thumbnail': 'http://books.google.com/books/content?id=x1&zoom=1&edge=curl'},
      },
      'accessInfo': {'viewability': 'ALL_PAGES', 'publicDomain': true, 'webReaderLink': 'http://play.google.com/r'},
    });
    expect(r.year, '1899');
    expect(r.description, 'Bentinho e Capitu');
    expect(r.categories, ['Ficção']);
    expect(r.coverUrl, startsWith('https://'));
    expect(r.coverUrl, isNot(contains('edge=curl')));
    expect(r.links.first.kind, LinkKind.read);
    expect(r.freeDigital, isTrue);
  });

  test('Open Library: empréstimo e ISBN brasileiro', () {
    final r = BooksApi.fromOpenLibrary({
      'key': '/works/OL1W',
      'title': 'Sapiens',
      'author_name': ['Yuval Noah Harari'],
      'isbn': ['9780062316097', '9788525432186'],
      'ebook_access': 'borrowable',
      'cover_i': 123,
    });
    expect(r.isbn13, '9788525432186');
    expect(r.links.first.label, contains('Emprestar'));
    expect(r.coverUrlLarge, 'https://covers.openlibrary.org/b/id/123-L.jpg');
  });

  test('OCR: pontuação e consultas', () {
    final r = BooksApi.fromOpenLibrary({'key': '/works/OL1W', 'title': 'Sapiens', 'author_name': ['Yuval Noah Harari']});
    final other = BooksApi.fromOpenLibrary({'key': '/works/OL2W', 'title': 'Homo Deus', 'author_name': ['Yuval Noah Harari']});
    final ocr = {'saplens', 'yuval', 'noah', 'harari'};
    expect(scoreResult(r, ocr), greaterThan(1.2));
    expect(scoreResult(r, ocr), greaterThan(scoreResult(other, ocr)));
    final q = queriesFromLines(const [OcrLine('SAPIENS', 120), OcrLine('Yuval Noah Harari', 40), OcrLine('Uma breve história', 30)]);
    expect(q.first, 'SAPIENS Yuval Noah Harari');
    expect(guessFromLines(const [OcrLine('SAPIENS', 120), OcrLine('YUVAL NOAH HARARI', 40)]).title, 'Sapiens');
  });

  test('regras de leitura', () {
    final b = AppState.applyRules(null, _book('A', status: ReadingStatus.read, total: 200));
    expect(b.pagesRead, 200);
    expect(b.finishedAt, isNotNull);
    expect(b.startedAt, isNotNull);
    expect(b.progress.single.pages, 200);
    final prev = b.copy();
    final c = AppState.applyRules(prev, b.copy()..status = ReadingStatus.reading);
    expect(c.finishedAt, isNull);
  });

  test('estatísticas', () {
    final y = DateTime.now().year;
    final s = Stats.of([
      _book('A', status: ReadingStatus.read, pages: 100, finished: '$y-03-10', cats: ['História']),
      _book('B', status: ReadingStatus.reading, pages: 50, cats: ['Fantasia']),
      _book('C'),
    ]);
    expect(s.total, 3);
    expect(s.readCount, 1);
    expect(s.readThisYear, 1);
    expect(s.pagesRead, 150);
    expect(s.finishedByMonth[2], 1);
    expect(s.genres.length, 2);
  });

  test('mesclar resultados completa campos', () {
    const a = SearchResult(key: 'google:1', provider: BookSource.google, providerId: '1', title: 'X');
    const b = SearchResult(key: 'openlibrary:1', provider: BookSource.openlibrary, providerId: '1', title: 'X', description: 'd', pageCount: 10);
    final m = a.mergeWith(b);
    expect(m.description, 'd');
    expect(m.pageCount, 10);
    expect(m.key, 'google:1');
  });
}
