import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/format.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = context.pal;
    final year = DateTime.now().year;
    final s = Stats.of(app.books, year: year);
    final goal = app.settings.yearlyGoal;
    final pct = (s.readThisYear / (goal < 1 ? 1 : goal) * 100).round();

    final top = s.genres.take(4).toList();
    final rest = s.genres.skip(4);
    final short = rest.isEmpty
        ? top
        : [...top, GenreStat('Outros', rest.fold(0, (a, g) => a + g.count), rest.fold(0.0, (a, g) => a + g.pct))];

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 30), children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, size: 26),
          const SizedBox(width: 10),
          const Text('Estatísticas', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          for (final (i, label) in const [(0, 'Geral'), (1, 'Tempo'), (2, 'Gêneros')]) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: Center(child: SizedBox(width: double.infinity, child: Pill(label: label, selected: tab == i, onTap: () => setState(() => tab = i))))),
          ],
        ]),
        const SizedBox(height: 16),
        if (app.books.isEmpty)
          Padding(padding: const EdgeInsets.all(40), child: Text('Adicione livros à sua estante para ver suas estatísticas.', textAlign: TextAlign.center, style: TextStyle(color: p.text2)))
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(tab),
              child: switch (tab) {
                0 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    StatCard(items: [
                      (Icons.menu_book_outlined, fmtInt(s.readCount), 'Livros lidos'),
                      (Icons.schedule_rounded, '${fmtInt(s.hours)}h', 'Tempo estimado'),
                      (Icons.star_rounded, s.avgRating > 0 ? fmtRating(s.avgRating) : '–', 'Média'),
                    ]),
                    const SectionHeader('Seu progresso'),
                    Row(children: [
                      _Ring(pct: pct),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Você leu '),
                          TextSpan(text: plural(s.readThisYear, 'livro', 'livros'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' em $year:\n'),
                          TextSpan(text: '$pct% da sua meta de ${plural(goal, 'livro', 'livros')}.', style: TextStyle(color: p.accent)),
                        ]), style: const TextStyle(fontSize: 15, height: 1.4)),
                      ),
                    ]),
                    if (short.isNotEmpty) ...[const SectionHeader('Gêneros mais lidos'), _GenreBars(genres: short)],
                    const SizedBox(height: 18),
                    Row(children: [
                      for (final (i, (n, l)) in [(s.readingCount, 'Lendo'), (s.wantCount, 'Quero ler'), (s.favorites, 'Favoritos'), (s.abandonedCount, 'Abandonados')].indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Panel(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(children: [
                              Text('$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                              Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.text2)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    StatCard(items: [
                      (Icons.bar_chart_rounded, fmtInt(s.pagesRead), 'Páginas lidas'),
                      (Icons.schedule_rounded, '${fmtInt(s.hours)}h', 'Tempo estimado'),
                      (Icons.menu_book_outlined, s.avgDays > 0 ? '${s.avgDays.round()}d' : '–', 'Por livro (média)'),
                    ]),
                    SectionHeader('Livros concluídos em $year'),
                    _MonthBars(values: s.finishedByMonth),
                    SectionHeader('Páginas lidas em $year'),
                    _MonthBars(values: s.pagesByMonth),
                    const SizedBox(height: 10),
                    Text('Páginas contadas a cada atualização de progresso. Tempo estimado com ${minPerPage.toString().replaceAll('.', ',')} min por página.',
                        style: TextStyle(color: p.text3, fontSize: 12)),
                  ]),
                _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionHeader('Todos os gêneros'),
                    _GenreBars(genres: s.genres),
                    if (s.authors.isNotEmpty) ...[
                      const SectionHeader('Autores na sua estante'),
                      for (final (i, (name, n)) in s.authors.indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                          child: Row(children: [
                            Text('${i + 1}. ', style: TextStyle(color: p.text3)),
                            Expanded(child: Text(name)),
                            Text(plural(n, 'livro', 'livros'), style: TextStyle(color: p.text2)),
                          ]),
                        ),
                    ],
                  ]),
              },
            ),
          ),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.pct});
  final int pct;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: 110,
      height: 110,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (pct / 100).clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(v, p.surface3, p.ink),
          child: Center(child: Text('$pct%', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.bg, this.fg);
  final double v;
  final Color bg, fg;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, paint..color = bg);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, paint..color = fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.fg != fg;
}

class _GenreBars extends StatelessWidget {
  const _GenreBars({required this.genres});
  final List<GenreStat> genres;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(children: [
      for (final (i, g) in genres.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 110, child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 12),
            Expanded(child: ProgressLine(value: g.pct, height: 7, color: Palette.chart[i % Palette.chart.length])),
            SizedBox(width: 46, child: Text('${(g.pct * 100).round()}%', textAlign: TextAlign.right, style: TextStyle(color: p.text2))),
          ]),
        ),
    ]);
  }
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.values});
  final List<int> values;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final max = values.fold<int>(1, (a, b) => b > a ? b : a);
    final now = DateTime.now().month - 1;
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 12; i++)
            Expanded(
              child: Opacity(
                opacity: i > now ? .45 : 1,
                child: Column(children: [
                  SizedBox(height: 14, child: Text(values[i] > 0 ? fmtInt(values[i]) : '', style: TextStyle(fontSize: 9.5, color: p.text2))),
                  Expanded(
                    child: Container(
                      width: 18,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: values[i] / max),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => FractionallySizedBox(
                          heightFactor: v,
                          child: Container(decoration: BoxDecoration(color: i == now ? p.ink : Palette.chart[0], borderRadius: BorderRadius.circular(6))),
                        ),
                      ),
                    ),
                  ),
                  Text(months[i][0].toUpperCase(), style: TextStyle(fontSize: 11, color: p.text2)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
