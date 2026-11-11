import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import 'book_form_screen.dart';
import 'scan_screen.dart';
import 'shell.dart';

/// Menu do botão "+": câmera, galeria, pesquisa ou cadastro manual.
Future<void> showAddSheet(BuildContext context) {
  final p = context.pal;
  Widget option(IconData icon, String title, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: p.inkText),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(sub, style: TextStyle(color: p.text2, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
  return showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Adicionar livro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          option(Icons.photo_camera_outlined, 'Fotografar a capa', 'Ou o código de barras. O app encontra o livro.', () {
            Navigator.pop(sheet);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
          }),
          option(Icons.image_outlined, 'Escolher foto da galeria', 'Uma foto da capa que você já tirou.', () async {
            Navigator.pop(sheet);
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 90);
            if (x != null && context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScanScreen(initialPhoto: x.path)));
            }
          }),
          option(Icons.search_rounded, 'Pesquisar na internet', 'Por título, autor, ISBN, editora ou categoria.', () {
            Navigator.pop(sheet);
            Shell.of(context)?.go(1);
          }),
          option(Icons.edit_outlined, 'Cadastrar manualmente', 'Preencha você mesmo as informações.', () {
            Navigator.pop(sheet);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookFormScreen()));
          }),
        ]),
      ),
    ),
  );
}
