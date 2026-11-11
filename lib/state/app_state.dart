import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../services/books_api.dart';
import '../services/format.dart';
import '../services/storage.dart';
import '../services/text_utils.dart';

/// Configurações e perfil.
class Settings {
  String name;
  String handle;
  String? avatarFile;
  ThemeMode theme;
  int yearlyGoal;
  String googleApiKey;
  bool onboarded;

  Settings({
    this.name = 'Leitor',
    this.handle = '',
    this.avatarFile,
    this.theme = ThemeMode.system,
    this.yearlyGoal = 12,
    this.googleApiKey = '',
    this.onboarded = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'handle': handle,
        'avatarFile': avatarFile,
        'theme': theme.name,
        'yearlyGoal': yearlyGoal,
        'googleApiKey': googleApiKey,
        'onboarded': onboarded,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        name: j['name'] as String? ?? 'Leitor',
        handle: j['handle'] as String? ?? '',
        avatarFile: j['avatarFile'] as String?,
        theme: ThemeMode.values.firstWhere((t) => t.name == j['theme'], orElse: () => ThemeMode.system),
        yearlyGoal: (j['yearlyGoal'] as num?)?.toInt() ?? 12,
        googleApiKey: j['googleApiKey'] as String? ?? '',
        onboarded: j['onboarded'] == true,
      );
}

/// Dados de um livro novo (vindo da pesquisa, da câmera ou do formulário).
class NewBook {
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
  String origin;
  String? originId;
  List<int>? coverBytes;
  String? coverUrl;
  ReadingStatus status;
  bool favorite;
  double rating;
  String notes;
  int pagesRead;
  String? startedAt;
  String? finishedAt;

  NewBook({
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
    this.origin = 'manual',
    this.originId,
    this.coverBytes,
    this.coverUrl,
    this.status = ReadingStatus.want,
    this.favorite = false,
    this.rating = 0,
    this.notes = '',
    this.pagesRead = 0,
    this.startedAt,
    this.finishedAt,
  });

  factory NewBook.fromResult(SearchResult r) => NewBook(
        title: r.title,
        subtitle: r.subtitle,
        authors: r.authors,
        publisher: r.publisher,
        year: r.year,
        description: r.description,
        categories: r.categories,
        pageCount: r.pageCount,
        isbn13: r.isbn13,
        isbn10: r.isbn10,
        language: r.language,
        links: r.links,
        origin: r.provider.name,
        originId: r.providerId,
      );
}

class AppState extends ChangeNotifier {
  AppState({Storage? storage, BooksApi? api})
      : storage = storage ?? Storage(),
        api = api ?? BooksApi();

  final Storage storage;
  final BooksApi api;
  bool ready = false;
  List<Book> books = [];
  Settings settings = Settings();
  SharedPreferences? _prefs;

  Future<void> init() async {
    await storage.open();
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('settings');
    if (raw != null) settings = Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    api.apiKey = settings.googleApiKey;
    books = await storage.allBooks();
    ready = true;
    notifyListeners();
  }

  Future<void> updateSettings(void Function(Settings s) change) async {
    change(settings);
    api.apiKey = settings.googleApiKey;
    await _prefs?.setString('settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Book? byId(String id) => books.where((b) => b.id == id).firstOrNull;

  /// Regras: começar marca a data de início; concluir marca o fim e completa
  /// as páginas. Toda mudança nas páginas lidas entra no histórico.
  static Book applyRules(Book? prev, Book b) {
    final today = todayIso();
    if (b.status == ReadingStatus.reading) b.startedAt ??= today;
    if (b.status == ReadingStatus.read) {
      b.startedAt ??= b.finishedAt ?? today;
      b.finishedAt ??= today;
      if (b.pageCount != null && b.pagesRead < b.pageCount!) b.pagesRead = b.pageCount!;
    }
    if (b.status != ReadingStatus.read && prev?.status == ReadingStatus.read && b.finishedAt == prev?.finishedAt) {
      b.finishedAt = null;
    }
    if (b.pageCount != null && b.pageCount! > 0 && b.pagesRead > b.pageCount!) b.pagesRead = b.pageCount!;
    if (b.pagesRead < 0) b.pagesRead = 0;
    if ((prev?.pagesRead ?? 0) != b.pagesRead) {
      b.progress = [...b.progress.where((p) => p.date != today), ProgressEntry(today, b.pagesRead)];
    }
    return b;
  }

  Future<Book> addBook(NewBook n) async {
    final cover = n.coverBytes != null ? await storage.saveCover(n.coverBytes!) : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final book = applyRules(
      null,
      Book(
        id: newId(),
        title: n.title,
        subtitle: n.subtitle,
        authors: n.authors,
        publisher: n.publisher,
        year: n.year,
        description: n.description,
        categories: n.categories,
        pageCount: n.pageCount,
        isbn13: n.isbn13,
        isbn10: n.isbn10,
        language: n.language,
        links: mergeLinks([n.links, shopLinks(title: n.title, authors: n.authors, isbn13: n.isbn13, isbn10: n.isbn10)]),
        coverFile: cover,
        coverUrl: cover == null ? n.coverUrl : null,
        origin: n.origin,
        originId: n.originId,
        status: n.status,
        favorite: n.favorite,
        rating: n.rating,
        notes: n.notes,
        pagesRead: n.pagesRead,
        startedAt: n.startedAt,
        finishedAt: n.finishedAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await storage.putBook(book);
    books = [book, ...books];
    notifyListeners();
    return book;
  }

  /// Adiciona direto de um resultado, baixando a capa para o aparelho.
  Future<Book> addFromResult(SearchResult r, {ReadingStatus status = ReadingStatus.want, bool favorite = false}) async {
    final bytes = await api.downloadImage([r.coverUrlLarge, r.coverUrl]);
    final n = NewBook.fromResult(r)
      ..status = status
      ..favorite = favorite
      ..coverBytes = bytes
      ..coverUrl = bytes == null ? (r.coverUrlLarge ?? r.coverUrl) : null;
    return addBook(n);
  }

  /// Altera um livro. [newCover]: bytes para trocar a capa, lista vazia para remover.
  Future<void> updateBook(String id, void Function(Book b) change, {List<int>? newCover}) async {
    final prev = byId(id);
    if (prev == null) return;
    final next = prev.copy();
    change(next);
    if (newCover != null) {
      await storage.deleteCover(prev.coverFile);
      next.coverFile = newCover.isEmpty ? null : await storage.saveCover(newCover);
      if (newCover.isNotEmpty) next.coverUrl = null;
    }
    next.updatedAt = DateTime.now().millisecondsSinceEpoch;
    applyRules(prev, next);
    await storage.putBook(next);
    books = [for (final b in books) b.id == id ? next : b];
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) => updateBook(id, (b) => b.favorite = !b.favorite);

  /// Remove e devolve o necessário para desfazer.
  Future<(Book, List<int>?)?> removeBook(String id) async {
    final b = byId(id);
    if (b == null) return null;
    List<int>? cover;
    if (b.coverFile != null) {
      final f = storage.coverFile(b.coverFile!);
      if (await f.exists()) cover = await f.readAsBytes();
    }
    await storage.deleteCover(b.coverFile);
    await storage.deleteBook(id);
    books = books.where((x) => x.id != id).toList();
    notifyListeners();
    return (b, cover);
  }

  Future<void> restoreBook(Book b, List<int>? cover) async {
    if (cover != null && b.coverFile != null) await storage.saveCover(cover, name: b.coverFile);
    await storage.putBook(b);
    books = [...books.where((x) => x.id != b.id), b]..sort((a, c) => c.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Book? findExisting({String? key, String? isbn13, required String title, List<String> authors = const []}) {
    for (final b in books) {
      if (key != null && '${b.origin}:${b.originId}' == key) return b;
      if (isbn13 != null && b.isbn13 == isbn13) return b;
      if (norm(b.title) == norm(title) && norm(b.firstAuthor) == norm(authors.isNotEmpty ? authors.first : '')) return b;
    }
    return null;
  }

  Future<void> wipe() async {
    await storage.clear();
    await _prefs?.clear();
    settings = Settings();
    books = [];
    notifyListeners();
  }

  // ------------------------------------------------------------------ Backup
  /// Gera um arquivo .json com a estante inteira, incluindo as capas.
  Future<File> exportBackup() async {
    final images = <String, String>{};
    for (final b in books) {
      if (b.coverFile == null) continue;
      final f = storage.coverFile(b.coverFile!);
      if (await f.exists()) images[b.coverFile!] = base64Encode(await f.readAsBytes());
    }
    final data = {
      'app': 'd-libery',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': (settings.toJson()..['googleApiKey'] = '')..remove('avatarFile'),
      'books': [for (final b in books) b.toJson()],
      'covers': images,
    };
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'd-libery-backup-${todayIso()}.json'));
    await file.writeAsString(jsonEncode(data));
    return file;
  }

  /// Restaura um backup, somando à estante atual. Aceita também o backup da versão web.
  Future<int> importBackup(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    if (data['app'] != 'd-libery' || data['books'] is! List) throw const FormatException('Arquivo de backup inválido');
    final covers = Map<String, dynamic>.from(data['covers'] as Map? ?? {});
    // Backup da versão web: imagens numa lista {id, data}, livros com coverId.
    for (final img in (data['images'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(img as Map);
      covers['${m['id']}.jpg'] = m['data'];
    }
    var n = 0;
    for (final raw in data['books'] as List) {
      final j = Map<String, dynamic>.from(raw as Map);
      if (j['coverId'] != null && j['coverFile'] == null) j['coverFile'] = '${j['coverId']}.jpg';
      final b = Book.fromJson(j);
      final c = b.coverFile != null ? covers[b.coverFile] as String? : null;
      if (c != null) await storage.saveCover(base64Decode(c), name: b.coverFile);
      if (c == null) b.coverFile = null;
      await storage.putBook(b);
      n++;
    }
    final s = data['settings'];
    if (s is Map) {
      final keep = settings.googleApiKey, avatar = settings.avatarFile;
      settings = Settings.fromJson(Map<String, dynamic>.from(s))
        ..googleApiKey = keep
        ..avatarFile = avatar
        ..onboarded = true;
      await _prefs?.setString('settings', jsonEncode(settings.toJson()));
    }
    books = await storage.allBooks();
    notifyListeners();
    return n;
  }
}
