import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/book.dart';

String newId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Livros no SQLite (um JSON por linha) e capas como arquivos JPG no aparelho.
class Storage {
  Database? _db;
  late Directory coversDir;

  Future<void> open() async {
    final docs = await getApplicationDocumentsDirectory();
    coversDir = Directory(p.join(docs.path, 'capas'));
    await coversDir.create(recursive: true);
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'd_libery.db'),
      version: 1,
      onCreate: (db, _) => db.execute('CREATE TABLE books (id TEXT PRIMARY KEY, data TEXT NOT NULL, createdAt INTEGER NOT NULL)'),
    );
  }

  Future<List<Book>> allBooks() async {
    final rows = await _db!.query('books', orderBy: 'createdAt DESC');
    return [for (final r in rows) Book.fromJson(jsonDecode(r['data'] as String) as Map<String, dynamic>)];
  }

  Future<void> putBook(Book b) => _db!.insert('books', {'id': b.id, 'data': b.encode(), 'createdAt': b.createdAt},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteBook(String id) => _db!.delete('books', where: 'id = ?', whereArgs: [id]);

  Future<void> clear() async {
    await _db!.delete('books');
    if (await coversDir.exists()) {
      await coversDir.delete(recursive: true);
      await coversDir.create(recursive: true);
    }
  }

  File coverFile(String name) => File(p.join(coversDir.path, name));

  Future<String> saveCover(List<int> bytes, {String? name}) async {
    final n = name ?? '${newId()}.jpg';
    await coverFile(n).writeAsBytes(bytes, flush: true);
    return n;
  }

  Future<void> deleteCover(String? name) async {
    if (name == null) return;
    final f = coverFile(name);
    if (await f.exists()) await f.delete();
  }
}
