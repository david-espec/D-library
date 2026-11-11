import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../services/updater.dart';
import '../theme.dart';

/// Procura versão nova; se houver, mostra o aviso "Atualizar".
/// [silent]: não avisa quando já está na última versão (verificação ao abrir o app).
Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
  UpdateInfo? u;
  try {
    u = await Updater.check();
  } catch (_) {
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem conexão para verificar atualizações')));
    }
    return;
  }
  if (!context.mounted) return;
  if (u == null) {
    if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você já está na versão mais nova 👍')));
    return;
  }
  await showModalBottomSheet(context: context, isDismissible: true, builder: (_) => _UpdateSheet(info: u!));
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.info});
  final UpdateInfo info;
  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  StreamSubscription<OtaEvent>? sub;
  double? progress;
  String? status;
  bool error = false;

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  void start() {
    setState(() {
      progress = 0;
      status = 'Baixando…';
      error = false;
    });
    sub = Updater.install(widget.info).listen(
      (e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              progress = (double.tryParse(e.value ?? '') ?? 0) / 100;
              status = 'Baixando… ${e.value ?? 0}%';
            case OtaStatus.INSTALLING:
            case OtaStatus.INSTALLATION_DONE:
              progress = 1;
              status = 'Toque em "Atualizar" na tela do Android.';
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              error = true;
              status = 'Permita que o D Libery instale atualizações (o Android vai pedir) e toque em “Tentar de novo”.';
            case OtaStatus.CHECKSUM_ERROR:
              error = true;
              status = 'O arquivo veio corrompido. Tente de novo.';
            default:
              error = true;
              status = 'Não foi possível atualizar (${e.value ?? e.status.name}). Tente de novo.';
          }
        });
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            error = true;
            status = 'Não foi possível atualizar: $e';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final busy = progress != null && !error;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.system_update_rounded, color: p.inkText),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nova versão disponível', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('D Libery ${widget.info.versionName}', style: TextStyle(color: p.text2)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Text('A atualização instala por cima do app atual. Seus livros, capas e anotações continuam aqui.',
              style: TextStyle(color: p.text2, fontSize: 13.5)),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: error ? 0 : progress, minHeight: 7, color: p.ink, backgroundColor: p.surface3),
            ),
            const SizedBox(height: 8),
            Text(status ?? '', style: TextStyle(fontSize: 13, color: error ? p.danger : p.text2)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: busy ? null : start,
            icon: const Icon(Icons.download_rounded),
            label: Text(error ? 'Tentar de novo' : busy ? 'Atualizando…' : 'Atualizar agora'),
          ),
          if (!busy) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Depois')),
        ]),
      ),
    );
  }
}
