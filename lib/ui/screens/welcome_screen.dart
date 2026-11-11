import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Boas-vindas: estante escura com luz de abajur, nome e meta anual.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int step = 0;
  final name = TextEditingController();
  int goal = 12;

  Future<void> finish() async {
    final n = name.text.trim().isEmpty ? 'Leitor' : name.text.trim();
    await context.read<AppState>().updateSettings((s) {
      s.name = n;
      s.handle = n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      s.yearlyGoal = goal;
      s.onboarded = true;
    });
  }

  Future<void> restore() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final path = picked.firstOrNull?.path;
    if (path == null || !mounted) return;
    try {
      final n = await context.read<AppState>().importBackup(await File(path).readAsString());
      if (mounted) toast(context, '$n livros restaurados');
    } catch (e) {
      if (mounted) toast(context, 'Não foi possível restaurar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0D0C),
        body: Stack(fit: StackFit.expand, children: [
          const CustomPaint(painter: _ShelvesPainter()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: Alignment(-.4, .25), radius: .9, colors: [Color(0x55FFC478), Color(0x00FFC478)]),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C0A0807), Color(0x330A0807), Color(0xEB0A0807)],
                stops: [0, .4, .85],
              ),
            ),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: step == 0 ? _intro() : _form(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _intro() => Padding(
        key: const ValueKey(0),
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
        child: Column(children: [
          const Spacer(flex: 3),
          const Icon(Icons.menu_book_outlined, size: 64, color: Color(0xFFF3EFE9)),
          const SizedBox(height: 10),
          Text('D Libery', style: serif.copyWith(fontSize: 58, color: const Color(0xFFF3EFE9), height: 1)),
          const SizedBox(height: 12),
          const Text('Sua biblioteca,\nem um só lugar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Color(0xD9F3EFE9))),
          const Spacer(flex: 4),
          SizedBox(
            width: 300,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF6F5F8), foregroundColor: const Color(0xFF141217), minimumSize: const Size(0, 54)),
              onPressed: () => setState(() => step = 1),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Começar'), SizedBox(width: 6), Icon(Icons.chevron_right_rounded)]),
            ),
          ),
          TextButton(onPressed: restore, child: const Text('Restaurar um backup', style: TextStyle(color: Color(0xFFE9E6EE)))),
        ]),
      );

  Widget _form() => SingleChildScrollView(
        key: const ValueKey(1),
        padding: const EdgeInsets.fromLTRB(28, 80, 28, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Vamos montar\nsua estante', style: serif.copyWith(fontSize: 38, color: Colors.white, height: 1.05)),
          const SizedBox(height: 8),
          const Text('Tudo fica guardado neste celular. Sem cadastro, sem anúncios.', style: TextStyle(color: Color(0xBFFFFFFF))),
          const SizedBox(height: 28),
          const Text('Como quer ser chamado?', style: TextStyle(color: Color(0xFFD6D2DC), fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Seu nome')),
          const SizedBox(height: 22),
          Text('Quantos livros quer ler em ${DateTime.now().year}?', style: const TextStyle(color: Color(0xFFD6D2DC), fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            IconButton.filledTonal(onPressed: () => setState(() => goal = goal > 1 ? goal - 1 : 1), icon: const Icon(Icons.remove)),
            Expanded(child: Text('$goal', textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white))),
            IconButton.filledTonal(onPressed: () => setState(() => goal++), icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 34),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF6F5F8), foregroundColor: const Color(0xFF141217), minimumSize: const Size.fromHeight(54)),
            onPressed: finish,
            child: const Text('Abrir minha biblioteca'),
          ),
        ]),
      );
}

/// Lombadas de livros em prateleiras, desenhadas (sem imagens externas).
class _ShelvesPainter extends CustomPainter {
  const _ShelvesPainter();
  static const _colors = [Color(0xFF4B2E23), Color(0xFF2C3B4A), Color(0xFF6A4B2B), Color(0xFF233227), Color(0xFF5B2425), Color(0xFF806240), Color(0xFF2B2441), Color(0xFF3A3020)];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    var seed = 7;
    int rnd(int m) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % m;
    const shelfH = 150.0;
    for (var y = 0.0; y < size.height; y += shelfH) {
      var x = 0.0;
      while (x < size.width) {
        final w = 10.0 + rnd(14);
        final h = shelfH - 22 - rnd(30);
        paint.color = _colors[rnd(_colors.length)].withValues(alpha: .55);
        canvas.drawRect(Rect.fromLTWH(x, y + shelfH - 12 - h, w - 1.5, h), paint);
        x += w;
      }
      paint.color = const Color(0xFF3A2A1C);
      canvas.drawRect(Rect.fromLTWH(0, y + shelfH - 12, size.width, 9), paint);
      paint.color = const Color(0xFF0D0A08);
      canvas.drawRect(Rect.fromLTWH(0, y + shelfH - 3, size.width, 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
