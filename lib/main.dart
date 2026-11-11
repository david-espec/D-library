import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState()..init();
  runApp(ChangeNotifierProvider.value(value: app, child: const DLiberyApp()));
}

class DLiberyApp extends StatelessWidget {
  const DLiberyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'D Libery',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: app.settings.theme,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: child!,
        );
      },
      home: !app.ready
          ? const _Boot()
          : app.settings.onboarded
              ? const Shell()
              : const WelcomeScreen(),
    );
  }
}

class _Boot extends StatelessWidget {
  const _Boot();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('D Libery', style: TextStyle(fontFamily: 'Cormorant', fontSize: 34, fontWeight: FontWeight.w600))));
}
