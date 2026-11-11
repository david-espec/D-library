import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../services/books_api.dart';
import '../../services/isbn.dart';
import '../../services/ocr.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_parts.dart';
import '../widgets/common.dart';
import 'book_form_screen.dart';

enum _Phase { camera, working, results }

/// Adicionar pela câmera: código de barras ao vivo ou foto da capa (ML Kit).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.initialPhoto});
  final String? initialPhoto;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final scanner = MobileScannerController(formats: const [BarcodeFormat.ean13], detectionSpeed: DetectionSpeed.normal);
  _Phase phase = _Phase.camera;
  String message = '';
  String? photo;
  String? isbn;
  List<OcrLine> lines = [];
  List<SearchResult> candidates = [];
  final query = TextEditingController();
  bool handling = false;
  String? picking;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto != null) {
      phase = _Phase.working;
      WidgetsBinding.instance.addPostFrameCallback((_) => _processPhoto(widget.initialPhoto!));
    }
  }

  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }

  AppState get app => context.read<AppState>();

  Future<void> _onBarcode(BarcodeCapture cap) async {
    if (handling || phase != _Phase.camera) return;
    for (final b in cap.barcodes) {
      final v = (b.rawValue ?? '').replaceAll(RegExp(r'\D'), '');
      if (isBookEan(v)) {
        handling = true;
        HapticFeedback.mediumImpact();
        await _lookupIsbn(v);
        return;
      }
    }
  }

  Future<void> _lookupIsbn(String code) async {
    await scanner.stop();
    setState(() {
      phase = _Phase.working;
      message = 'Código $code lido. Procurando o livro…';
      isbn = code;
    });
    List<SearchResult> rs = [];
    try {
      rs = await app.api.lookupIsbn(code);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      candidates = rs.take(6).toList();
      query.text = code;
      phase = _Phase.results;
    });
  }

  Future<void> _takePhoto(ImageSource src) async {
    await scanner.stop();
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1800, imageQuality: 90);
    if (x == null) {
      if (mounted) await scanner.start();
      return;
    }
    await _processPhoto(x.path);
  }

  Future<void> _processPhoto(String path) async {
    setState(() {
      photo = path;
      phase = _Phase.working;
      message = 'Procurando código de barras';
    });
    final code = await isbnFromPhoto(path);
    if (code != null) return _lookupIsbn(code);
    try {
      final rec = await recognizeCover(path, app.api, onStep: (m) => mounted ? setState(() => message = m) : null);
      if (!mounted) return;
      setState(() {
        lines = rec.lines;
        candidates = rec.candidates.map((c) => c.result).toList();
        query.text = rec.queries.firstOrNull ?? '';
        phase = _Phase.results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => phase = _Phase.results);
      // Na primeira vez o Google Play pode ainda estar baixando o leitor de texto.
      final downloading = RegExp('download|module|unavailable', caseSensitive: false).hasMatch('$e');
      toast(
        context,
        downloading
            ? 'O leitor de texto do Google ainda está sendo baixado. Tente de novo em instantes (precisa de internet).'
            : 'Não consegui ler a capa. Você pode pesquisar ou cadastrar manualmente.',
      );
    }
  }

  Future<void> _research() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      phase = _Phase.working;
      message = 'Procurando "$q"';
    });
    try {
      final out = await app.api.search(q, SearchField.all);
      if (mounted) setState(() => candidates = out.results.take(12).toList());
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => phase = _Phase.results);
  }

  Future<void> _pick(SearchResult r) async {
    setState(() => picking = r.key);
    final full = await app.api.details(r).catchError((_) => r);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BookFormScreen(fromResult: full, photoPath: photo)));
  }

  void _manual() {
    final g = guessFromLines(lines);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BookFormScreen(
        photoPath: photo,
        draft: NewBook(title: g.title, authors: g.author.isEmpty ? const [] : [g.author], isbn13: isbn),
      ),
    ));
  }

  void _retake() {
    setState(() {
      phase = _Phase.camera;
      photo = null;
      isbn = null;
      lines = [];
      candidates = [];
      handling = false;
    });
    scanner.start();
  }

  @override
  Widget build(BuildContext context) => switch (phase) {
        _Phase.camera => _camera(),
        _Phase.working => _working(),
        _Phase.results => _results(),
      };

  Widget _camera() {
    final size = MediaQuery.of(context).size;
    final fw = (size.width * .74).clamp(0.0, 360.0);
    final frame = Rect.fromCenter(center: Offset(size.width / 2, size.height * .45), width: fw, height: fw * 1.5);
    Widget roundBtn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black38,
            foregroundColor: Colors.white,
            minimumSize: const Size(52, 52),
            side: const BorderSide(color: Colors.white38),
          ),
          icon: Icon(icon),
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: scanner,
          onDetect: _onBarcode,
          errorBuilder: (context, error) => _NoCamera(
            reason: error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'O acesso à câmera foi negado. Libere nas configurações do Android ou use as opções abaixo.'
                : 'Não foi possível abrir a câmera.',
            onPhoto: () => _takePhoto(ImageSource.camera),
            onGallery: () => _takePhoto(ImageSource.gallery),
          ),
        ),
        IgnorePointer(child: CustomPaint(painter: _FramePainter(frame))),
        const _Laser(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              roundBtn(Icons.close_rounded, 'Fechar', () => Navigator.pop(context)),
              ValueListenableBuilder(
                valueListenable: scanner,
                builder: (_, state, _) => state.torchState == TorchState.unavailable
                    ? const SizedBox()
                    : roundBtn(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded, 'Lanterna', scanner.toggleTorch),
              ),
            ]),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 150 + MediaQuery.of(context).padding.bottom,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
              child: const Text('Aponte para o código de barras — ou toque no botão para fotografar a capa',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ),
        Positioned(
          left: 34,
          right: 34,
          bottom: 34 + MediaQuery.of(context).padding.bottom,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            roundBtn(Icons.image_outlined, 'Galeria', () => _takePhoto(ImageSource.gallery)),
            Semantics(
              label: 'Fotografar capa',
              button: true,
              child: GestureDetector(
                onTap: () => _takePhoto(ImageSource.camera),
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: const DecoratedBox(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ),
            ),
            roundBtn(Icons.cameraswitch_outlined, 'Trocar câmera', scanner.switchCamera),
          ]),
        ),
      ]),
    );
  }

  Widget _working() {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 210,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Stack(fit: StackFit.expand, children: [
                      photo != null ? Image.file(File(photo!), fit: BoxFit.cover) : Container(color: p.surface2, child: Icon(Icons.qr_code_2_rounded, size: 60, color: p.text2)),
                      const _Sweep(),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(width: 200, child: LinearProgressIndicator(minHeight: 3, color: p.ink, backgroundColor: p.surface3)),
              const SizedBox(height: 18),
              TextButton(onPressed: _retake, child: const Text('Cancelar')),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final p = context.pal;
    final best = candidates.firstOrNull;
    final others = candidates.skip(1).toList();
    final existing = best == null ? null : app.findExisting(key: best.key, isbn13: best.isbn13, title: best.title, authors: best.authors);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(best != null ? 'É este livro?' : 'Livro não identificado'),
        actions: [IconButton(onPressed: _retake, icon: const Icon(Icons.photo_camera_outlined), tooltip: 'Tirar outra foto')],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40), children: [
        if (best != null)
          Panel(
            child: InkWell(
              onTap: picking == null ? () => _pick(best) : null,
              child: Row(children: [
                SizedBox(
                  width: 112,
                  height: 158,
                  child: Stack(children: [
                    if (photo != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Transform.rotate(
                          angle: -.12,
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: p.surface, width: 2), borderRadius: BorderRadius.circular(6)),
                            child: ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.file(File(photo!), width: 62, height: 90, fit: BoxFit.cover)),
                          ),
                        ),
                      ),
                    Positioned(right: 0, bottom: 0, child: CoverImage(title: best.title, author: best.authors.firstOrNull, url: best.coverUrl, width: 92)),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(best.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
                    Text(best.authors.join(', '), style: TextStyle(color: p.text2, fontSize: 13)),
                    Text([best.publisher, best.year].whereType<String>().join(' · '), style: TextStyle(color: p.text2, fontSize: 12)),
                    if (existing != null) const Padding(padding: EdgeInsets.only(top: 6), child: Tag('Já está na sua estante')),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: picking == null ? () => _pick(best) : null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(picking == best.key ? 'Abrindo…' : 'Sim, é este'),
                    ),
                  ]),
                ),
              ]),
            ),
          )
        else
          Column(children: [
            if (photo != null)
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photo!), width: 120, height: 180, fit: BoxFit.cover)),
            const SizedBox(height: 14),
            Text(
              '${isbn != null ? 'Não encontrei o ISBN $isbn nas bases públicas.' : 'Não encontrei este livro automaticamente.'} '
              'Você pode pesquisar com outras palavras ou cadastrá-lo usando a foto como capa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text2),
            ),
          ]),
        if (others.isNotEmpty) ...[
          const SectionHeader('Outras possibilidades'),
          for (final r in others)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: CoverImage(title: r.title, url: r.coverUrl, width: 44, radius: 4),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${r.authors.join(', ')}${r.year != null ? ' · ${r.year}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: picking == null ? () => _pick(r) : null,
            ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _research(),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Título ou autor da capa'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.surface2, foregroundColor: p.text),
            onPressed: _research,
            child: const Text('Pesquisar'),
          ),
        ]),
        if (lines.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Texto lido na capa', style: TextStyle(fontSize: 13, color: p.text2)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(lines.map((l) => l.text).join(' · '), style: TextStyle(color: p.text2, fontSize: 13)))],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _manual,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(best != null ? 'Nenhum destes — cadastrar manualmente' : 'Cadastrar manualmente com esta foto'),
        ),
        TextButton(onPressed: _retake, child: const Text('Tirar outra foto')),
      ]),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.reason, required this.onPhoto, required this.onGallery});
  final String reason;
  final VoidCallback onPhoto, onGallery;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121014),
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 46),
        const SizedBox(height: 14),
        Text(reason, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          onPressed: onPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Abrir câmera do aparelho'),
        ),
        TextButton(onPressed: onGallery, child: const Text('Escolher da galeria', style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}

/// Escurece fora da moldura e desenha os cantos.
class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);
  final Rect frame;
  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(16)));
    canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), Paint()..color = Colors.black.withValues(alpha: .45));
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 34.0;
    final r = frame;
    for (final (o, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(o, o + Offset(l * dx, 0), p);
      canvas.drawLine(o, o + Offset(0, l * dy), p);
    }
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.frame != frame;
}

class _Laser extends StatefulWidget {
  const _Laser();
  @override
  State<_Laser> createState() => _LaserState();
}

class _LaserState extends State<_Laser> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fw = (size.width * .74).clamp(0.0, 360.0);
    final top = size.height * .45 - fw * .75;
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) => Positioned(
        left: (size.width - fw) / 2 + fw * .08,
        width: fw * .84,
        top: top + fw * 1.5 * (.1 + .8 * Curves.easeInOut.transform(c.value)),
        child: IgnorePointer(
          child: Container(
            height: 2,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white70, Colors.transparent])),
          ),
        ),
      ),
    );
  }
}

class _Sweep extends StatefulWidget {
  const _Sweep();
  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0x00789AFF), Color(0x5978AAFF), Color(0x00789AFF)],
              stops: [(c.value - .15).clamp(0, 1), c.value, (c.value + .15).clamp(0, 1)],
            ),
          ),
        ),
      );
}
