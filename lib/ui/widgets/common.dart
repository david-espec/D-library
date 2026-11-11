import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Capa: arquivo guardado, imagem da internet ou capa gerada com o título.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.title, this.author, this.file, this.url, this.fallbackUrl, this.width, this.radius = 6, this.bytes});

  final String title;
  final String? author;
  final File? file;
  final String? url;
  final String? fallbackUrl;
  final double? width;
  final double radius;
  final List<int>? bytes;

  factory CoverImage.book(BuildContext context, Book b, {double? width, double radius = 6}) {
    final st = context.read<AppState>().storage;
    return CoverImage(
      title: b.title,
      author: b.firstAuthor,
      file: b.coverFile != null ? st.coverFile(b.coverFile!) : null,
      url: b.coverUrl,
      width: width,
      radius: radius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = _Placeholder(title: title, author: author, small: (width ?? 100) < 70);
    Widget img;
    if (bytes != null) {
      img = Image.memory(Uint8List.fromList(bytes!), fit: BoxFit.cover);
    } else if (file != null) {
      img = Image.file(file!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _net(url, ph));
    } else {
      img = _net(url, ph);
    }
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * .7),
          bottomLeft: Radius.circular(radius * .7),
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x2E000000), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x47000000), blurRadius: 14, offset: Offset(0, 6), spreadRadius: -4),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius * .7),
          bottomLeft: Radius.circular(radius * .7),
          topRight: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
        ),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(fit: StackFit.expand, children: [
            img,
            // Dobra da lombada.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x2E000000), Color(0x1FFFFFFF), Color(0x00000000)],
                  stops: [0, .025, .06],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _net(String? u, Widget ph) {
    final first = u ?? fallbackUrl;
    if (first == null) return ph;
    return Image.network(
      first,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) => prog == null ? child : Container(color: const Color(0x14000000)),
      errorBuilder: (_, _, _) => fallbackUrl != null && fallbackUrl != first
          ? Image.network(fallbackUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => ph)
          : ph,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, this.author, this.small = false});
  final String title;
  final String? author;
  final bool small;

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in title.codeUnits) {
      h = (h * 31 + c) % 360;
    }
    final c1 = HSLColor.fromAHSL(1, h.toDouble(), .38, .34).toColor();
    final c2 = HSLColor.fromAHSL(1, (h + 30) % 360.0, .42, .20).toColor();
    final fg = HSLColor.fromAHSL(1, h.toDouble(), .6, .92).toColor();
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2])),
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 10, vertical: small ? 6 : 14),
      child: LayoutBuilder(builder: (context, c) {
        final fs = (c.maxWidth / 6).clamp(7.0, 22.0);
        return Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis,
              style: serif.copyWith(color: fg, fontSize: fs, height: 1.1)),
          if (author != null && author!.isNotEmpty && !small)
            Text(author!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg.withValues(alpha: .8), fontSize: fs * .62)),
        ]);
      }),
    );
  }
}

/// Estrelas de 0 a 5 com meio ponto. Toque na metade esquerda = meia estrela.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.value, this.onChanged, this.size = 22});
  final double value;
  final ValueChanged<double>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: EdgeInsets.only(right: size * .18),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onChanged == null
                ? null
                : (d) {
                    final half = d.localPosition.dx < size / 2;
                    final v = half ? i - .5 : i.toDouble();
                    onChanged!(value == v ? 0 : v);
                  },
            child: Semantics(
              label: '$i estrelas',
              button: onChanged != null,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(children: [
                  Icon(Icons.star_rounded, size: size, color: p.surface3),
                  ClipRect(
                    clipper: _Frac((value - (i - 1)).clamp(0, 1).toDouble()),
                    child: Icon(Icons.star_rounded, size: size, color: p.star),
                  ),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Frac extends CustomClipper<Rect> {
  _Frac(this.f);
  final double f;
  @override
  Rect getClip(Size s) => Rect.fromLTWH(0, 0, s.width * f, s.height);
  @override
  bool shouldReclip(_Frac o) => o.f != f;
}

/// Cartão escuro com três números (Livros, Páginas, Avaliação…).
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.items});
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: p.statBg, borderRadius: BorderRadius.circular(18)),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) VerticalDivider(color: p.statText.withValues(alpha: .18), width: 1),
            Expanded(
              child: Column(children: [
                Icon(items[i].$1, color: p.statText.withValues(alpha: .9), size: 21),
                const SizedBox(height: 4),
                Text(items[i].$2, style: TextStyle(color: p.statText, fontSize: 20, fontWeight: FontWeight.w700)),
                Text(items[i].$3, textAlign: TextAlign.center, style: TextStyle(color: p.statText.withValues(alpha: .78), fontSize: 11.5)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Pílula selecionável (filtros).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.selected = false, this.onTap, this.count, this.small = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: selected ? p.ink : p.surface2,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 15, vertical: small ? 6 : 8),
          child: Text.rich(
            TextSpan(text: label, children: [
              if (count != null) TextSpan(text: '  $count', style: TextStyle(color: (selected ? p.inkText : p.text).withValues(alpha: .55), fontSize: 12)),
            ]),
            style: TextStyle(color: selected ? p.inkText : p.text, fontSize: small ? 12.5 : 13.5, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// Seletor segmentado (status da leitura, abas).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.values, required this.value, required this.label, required this.onChanged});
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(999)),
      child: Row(children: [
        for (final v in values)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: v == value ? p.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.center,
                child: Text(label(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: v == value ? p.inkText : p.text2)),
              ),
            ),
          ),
      ]),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, this.height = 6, this.color});
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height, backgroundColor: p.surface3, color: color ?? p.ink),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Text(action!, style: TextStyle(fontSize: 13, color: context.pal.text2)),
                Icon(Icons.chevron_right_rounded, size: 18, color: context.pal.text2),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Bloco branco arredondado.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: p == Palette.dark ? Border.all(color: p.line) : null,
        boxShadow: p == Palette.dark ? null : const [BoxShadow(color: Color(0x0F141217), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -10)],
      ),
      child: child,
    );
  }
}

void toast(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text),
    duration: Duration(seconds: action != null ? 5 : 3),
    action: action != null ? SnackBarAction(label: action, onPressed: onAction ?? () {}) : null,
  ));
}

Future<bool> confirm(BuildContext context, {required String title, String? text, String ok = 'Confirmar', bool danger = false}) async {
  final p = context.pal;
  final r = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (text != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(text, style: TextStyle(color: p.text2))),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            const SizedBox(width: 8),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white) : null,
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok),
            ),
          ]),
        ]),
      ),
    ),
  );
  return r ?? false;
}
