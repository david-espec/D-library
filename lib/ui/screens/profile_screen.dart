import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/format.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/update_sheet.dart';
import '../../services/updater.dart';
import 'library_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = context.pal;
    final s = Stats.of(app.books);
    final st = app.settings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    void shelf(String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryScreen(initialShelf: id)));

    Widget row(IconData icon, String label, {VoidCallback? onTap, Widget? trailing}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              Icon(icon, size: 21),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5))),
              trailing ?? Icon(Icons.chevron_right_rounded, color: p.text3),
            ]),
          ),
        );
    Widget group(List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) Divider(color: p.line, height: 1), rows[i]],
            ]),
          ),
        );
    Widget value(String v) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(v, style: TextStyle(color: p.text2, fontSize: 13)),
          Icon(Icons.chevron_right_rounded, color: p.text3),
        ]);

    final avatar = st.avatarFile != null ? app.storage.coverFile(st.avatarFile!) : null;

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
        Row(children: [
          GestureDetector(
            onTap: () => _changeAvatar(context),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: p.surface2,
              backgroundImage: avatar != null && avatar.existsSync() ? FileImage(avatar) : null,
              child: avatar == null ? Icon(Icons.person_rounded, size: 34, color: p.text2) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              if (st.handle.isNotEmpty) Text('@${st.handle}', style: TextStyle(color: p.text2)),
            ]),
          ),
          IconButton(onPressed: () => _editProfile(context), icon: const Icon(Icons.edit_outlined), tooltip: 'Editar perfil'),
        ]),
        const SizedBox(height: 16),
        StatCard(items: [
          (Icons.menu_book_outlined, fmtInt(s.total), 'Livros'),
          (Icons.schedule_rounded, '${fmtInt(s.hours)}h', 'Lidas (est.)'),
          (Icons.star_rounded, s.avgRating > 0 ? fmtRating(s.avgRating) : '–', 'Avaliação'),
        ]),
        group([
          row(Icons.local_library_outlined, 'Minha biblioteca', onTap: () => shelf('all')),
          row(Icons.favorite_border_rounded, 'Favoritos', onTap: () => shelf('fav')),
          row(Icons.bookmark_border_rounded, 'Lista de desejos', onTap: () => shelf('want')),
          row(Icons.flag_outlined, 'Meta anual', onTap: () => _editGoal(context), trailing: value('${st.yearlyGoal} livros')),
        ]),
        group([
          row(Icons.dark_mode_outlined, 'Modo escuro',
              onTap: () => app.updateSettings((x) => x.theme = dark ? ThemeMode.light : ThemeMode.dark),
              trailing: Switch(
                value: dark,
                activeTrackColor: p.ink,
                onChanged: (v) => app.updateSettings((x) => x.theme = v ? ThemeMode.dark : ThemeMode.light),
              )),
          row(Icons.contrast_rounded, 'Tema', onTap: () => _theme(context), trailing: value(switch (st.theme) {
            ThemeMode.system => 'Automático',
            ThemeMode.light => 'Claro',
            ThemeMode.dark => 'Escuro',
          })),
          row(Icons.key_outlined, 'Chave do Google Books (opcional)', onTap: () => _apiKey(context), trailing: value(st.googleApiKey.isEmpty ? 'Não' : 'Configurada')),
        ]),
        group([
          row(Icons.upload_file_outlined, 'Exportar backup', onTap: () async {
            final f = await app.exportBackup();
            await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'Backup do D Libery (${app.books.length} livros)'));
          }),
          row(Icons.download_outlined, 'Restaurar backup', onTap: () async {
            final picked = await FilePicker.pickFiles(type: FileType.any);
            final path = picked.firstOrNull?.path;
            if (path == null || !context.mounted) return;
            try {
              final n = await app.importBackup(await File(path).readAsString());
              if (context.mounted) toast(context, '$n livros restaurados');
            } catch (e) {
              if (context.mounted) toast(context, 'Não foi possível restaurar: $e');
            }
          }),
          row(Icons.system_update_rounded, 'Verificar atualizações',
              onTap: () => checkForUpdate(context, silent: false),
              trailing: FutureBuilder(
                future: Updater.current(),
                builder: (_, s) => value(s.hasData ? 'v${s.data!.name}' : ''),
              )),
          row(Icons.info_outline_rounded, 'Sobre o app', onTap: () => _about(context)),
          row(Icons.delete_outline_rounded, 'Apagar todos os dados', onTap: () async {
            final ok = await confirm(context,
                title: 'Apagar todos os dados?',
                text: 'Todos os livros, capas, anotações e configurações serão apagados. Exporte um backup antes, se quiser guardar.',
                ok: 'Apagar tudo',
                danger: true);
            if (ok) await app.wipe();
          }),
        ]),
      ]),
    );
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final app = context.read<AppState>();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 85);
    if (x == null) return;
    await app.storage.deleteCover(app.settings.avatarFile);
    final name = await app.storage.saveCover(await File(x.path).readAsBytes());
    await app.updateSettings((s) => s.avatarFile = name);
  }

  Future<void> _sheet(BuildContext context, String title, Widget Function(BuildContext, StateSetter) body) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (c, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              body(c, set),
            ]),
          ),
        ),
      );

  void _editProfile(BuildContext context) {
    final app = context.read<AppState>();
    final name = TextEditingController(text: app.settings.name);
    final handle = TextEditingController(text: app.settings.handle);
    _sheet(context, 'Editar perfil', (c, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 10),
          TextField(controller: handle, decoration: const InputDecoration(labelText: 'Usuário')),
          if (app.settings.avatarFile != null)
            TextButton(
              onPressed: () async {
                await app.storage.deleteCover(app.settings.avatarFile);
                await app.updateSettings((s) => s.avatarFile = null);
              },
              child: const Text('Remover foto'),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              await app.updateSettings((s) {
                s.name = name.text.trim().isEmpty ? 'Leitor' : name.text.trim();
                s.handle = handle.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
              });
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ]));
  }

  void _editGoal(BuildContext context) {
    final app = context.read<AppState>();
    var goal = app.settings.yearlyGoal;
    _sheet(context, 'Meta de leitura de ${DateTime.now().year}', (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(onPressed: () => set(() => goal = goal > 1 ? goal - 1 : 1), icon: const Icon(Icons.remove)),
            SizedBox(width: 110, child: Text('$goal', textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700))),
            IconButton.filledTonal(onPressed: () => set(() => goal++), icon: const Icon(Icons.add)),
          ]),
          Text('livros por ano · cerca de ${(goal / 12).toStringAsFixed(1).replaceAll('.', ',')} por mês',
              textAlign: TextAlign.center, style: TextStyle(color: c.pal.text2, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await app.updateSettings((s) => s.yearlyGoal = goal);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ]));
  }

  void _theme(BuildContext context) {
    final app = context.read<AppState>();
    _sheet(context, 'Tema', (c, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Segmented<ThemeMode>(
            values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
            value: app.settings.theme,
            label: (m) => switch (m) { ThemeMode.system => 'Automático', ThemeMode.light => 'Claro', ThemeMode.dark => 'Escuro' },
            onChanged: (m) async {
              await app.updateSettings((s) => s.theme = m);
              set(() {});
            },
          ),
          const SizedBox(height: 10),
          Text('“Automático” acompanha o modo claro/escuro do celular.', style: TextStyle(color: c.pal.text2, fontSize: 13)),
        ]));
  }

  void _apiKey(BuildContext context) {
    final app = context.read<AppState>();
    final key = TextEditingController(text: app.settings.googleApiKey);
    _sheet(context, 'Chave do Google Books', (c, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'A pesquisa funciona sem chave. Se aparecer aviso de “limite de consultas”, crie uma chave gratuita no '
            'Google Cloud Console (API “Books”) e cole aqui. Ela fica só neste celular e não entra no backup.',
            style: TextStyle(color: c.pal.text2, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(controller: key, decoration: const InputDecoration(labelText: 'Chave da API', hintText: 'AIza…')),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () async {
              await app.updateSettings((s) => s.googleApiKey = key.text.trim());
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ]));
  }

  void _about(BuildContext context) {
    _sheet(context, 'Sobre o D Libery', (c, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sua biblioteca digital pessoal. Pesquise livros, fotografe capas, organize sua estante e acompanhe suas leituras.'),
          const SizedBox(height: 12),
          for (final t in const [
            'Dados de livros: Google Books e Open Library.',
            'Leitura de capas e de código de barras feita no próprio celular (Google ML Kit). Suas fotos não são enviadas a nenhum servidor.',
            'Seus livros, capas e anotações ficam só neste celular. Use o backup para levar para outro.',
            'O app não guarda nem distribui livros protegidos: os links “ler grátis” apontam apenas para versões legais.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5)))]),
            ),
        ]));
  }
}
