import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/book.dart';
import 'books_api.dart';
import 'isbn.dart';
import 'text_utils.dart';

class OcrLine {
  final String text;
  final double height;
  const OcrLine(this.text, this.height);
}

class ScoredResult {
  final SearchResult result;
  final double score;
  const ScoredResult(this.result, this.score);
}

class CoverRecognition {
  final List<OcrLine> lines;
  final List<String> queries;
  final List<ScoredResult> candidates;
  const CoverRecognition(this.lines, this.queries, this.candidates);
}

/// Procura um ISBN (código de barras EAN-13 978/979) numa foto.
Future<String?> isbnFromPhoto(String path) async {
  try {
    final cap = await MobileScannerController(autoStart: false)
        .analyzeImage(path, formats: const [BarcodeFormat.ean13]);
    for (final b in cap?.barcodes ?? const <Barcode>[]) {
      final v = (b.rawValue ?? '').replaceAll(RegExp(r'\D'), '');
      if (isBookEan(v)) return v;
    }
  } catch (_) {}
  return null;
}

/// Lê o texto da capa com o ML Kit (no próprio aparelho, sem internet).
Future<List<OcrLine>> readCoverText(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final rec = await recognizer.processImage(InputImage.fromFilePath(path));
    final lines = <OcrLine>[];
    for (final block in rec.blocks) {
      for (final l in block.lines) {
        final text = l.text.replaceAll(RegExp(r"[^\p{L}\d' :.\-]", unicode: true), '').trim();
        if (text.length < 2 || !RegExp(r'[\p{L}\d]{2,}', unicode: true).hasMatch(text)) continue;
        // Linha "deitada" (texto na lombada) vale pela largura.
        final h = l.boundingBox.height < l.boundingBox.width ? l.boundingBox.height : l.boundingBox.width;
        lines.add(OcrLine(text, h));
      }
    }
    lines.sort((a, b) => b.height.compareTo(a.height));
    return lines;
  } finally {
    await recognizer.close();
  }
}

List<String> _tokens(String s) => norm(s).split(' ').where((t) => t.length >= 3).toList();

/// Quanto o resultado combina com o texto lido na capa.
double scoreResult(SearchResult r, Set<String> ocr) {
  final title = _tokens(r.title);
  final author = _tokens(r.authors.join(' '));
  if (title.isEmpty) return 0;
  bool found(String t) => ocr.contains(t) || ocr.any((o) => closeEnough(t, o));
  final hitT = title.where(found).length / title.length;
  final hitA = author.isEmpty ? 0 : author.where(found).length / author.length;
  return hitT + hitA * 0.6 + (r.coverUrl != null ? 0.05 : 0);
}

/// Consultas a partir das linhas lidas: as maiores costumam ser título e autor.
List<String> queriesFromLines(List<OcrLine> lines) {
  final big = lines.take(3).map((l) => l.text).toList();
  final all = lines.take(6).map((l) => l.text).join(' ').split(' ').take(10).join(' ');
  final qs = <String>[
    if (big.isNotEmpty) big.take(2).join(' '),
    if (big.isNotEmpty) big.first,
    all,
  ];
  final out = <String>[];
  for (final q in qs) {
    if (norm(q).length >= 3 && !out.contains(q)) out.add(q);
  }
  return out;
}

/// Reconhece o livro: lê a capa e pesquisa o texto nas duas fontes.
Future<CoverRecognition> recognizeCover(String path, BooksApi api, {void Function(String)? onStep}) async {
  onStep?.call('Lendo o texto da capa');
  final lines = await readCoverText(path);
  final ocr = lines.expand((l) => _tokens(l.text)).toSet();
  final queries = queriesFromLines(lines);
  final seen = <String, ScoredResult>{};
  for (final q in queries) {
    onStep?.call('Procurando "$q"');
    try {
      final out = await api.search(q, SearchField.all);
      for (final r in out.results) {
        seen.putIfAbsent(r.key, () => ScoredResult(r, scoreResult(r, ocr)));
      }
    } catch (_) {}
    if (seen.values.any((s) => s.score >= 1.2)) break; // título e autor batem
  }
  final list = seen.values.where((s) => s.score > 0.25).toList()..sort((a, b) => b.score.compareTo(a.score));
  return CoverRecognition(lines, queries, list.take(12).toList());
}

String _cap(String s) => s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// Título e autor sugeridos para o cadastro manual.
({String title, String author}) guessFromLines(List<OcrLine> lines) =>
    (title: lines.isNotEmpty ? _cap(lines[0].text) : '', author: lines.length > 1 ? _cap(lines[1].text) : '');
