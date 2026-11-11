import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/update_sheet.dart';
import 'add_sheet.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'stats_screen.dart';

/// Estrutura principal: Biblioteca, Pesquisa, (+), Estatísticas, Perfil.
class Shell extends StatefulWidget {
  const Shell({super.key});
  static ShellState? of(BuildContext context) => context.findAncestorStateOfType<ShellState>();
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int tab = 0;
  final _searchKey = GlobalKey<SearchScreenState>();

  @override
  void initState() {
    super.initState();
    // Ao abrir o app, procura versão nova (sem incomodar se não houver).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) checkForUpdate(context);
    });
  }

  void go(int i, {String? searchQuery}) {
    setState(() => tab = i);
    if (i == 1 && searchQuery != null) WidgetsBinding.instance.addPostFrameCallback((_) => _searchKey.currentState?.runQuery(searchQuery));
    if (i == 1 && searchQuery == null) WidgetsBinding.instance.addPostFrameCallback((_) => _searchKey.currentState?.focus());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: tab, children: [
          const HomeScreen(),
          SearchScreen(key: _searchKey),
          const StatsScreen(),
          const ProfileScreen(),
        ]),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 70,
              child: Row(children: [
                _item(0, Icons.home_rounded, Icons.home_outlined, 'Biblioteca'),
                _item(1, Icons.search_rounded, Icons.search_rounded, 'Pesquisa'),
                Expanded(
                  child: Center(
                    child: Material(
                      color: p.ink,
                      shape: const CircleBorder(),
                      elevation: 3,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => showAddSheet(context),
                        child: SizedBox(width: 54, height: 54, child: Icon(Icons.add_rounded, color: p.inkText, size: 28, semanticLabel: 'Adicionar livro')),
                      ),
                    ),
                  ),
                ),
                _item(2, Icons.bar_chart_rounded, Icons.bar_chart_rounded, 'Estatísticas'),
                _item(3, Icons.person_rounded, Icons.person_outline_rounded, 'Perfil'),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData on, IconData off, String label) {
    final p = context.pal;
    final sel = tab == i;
    return Expanded(
      child: InkResponse(
        onTap: () => go(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(sel ? on : off, color: sel ? p.text : p.text3, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, color: sel ? p.text : p.text3, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}
