import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Endereços fixos da release "apk" (atualizada a cada build do GitHub Actions).
const _base = 'https://github.com/david-espec/D-library/releases/download/apk';
const apkUrl = '$_base/D-Libery.apk';
const _versionUrl = '$_base/version.json';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String? sha256;
  const UpdateInfo(this.versionCode, this.versionName, this.sha256);
}

class Updater {
  /// Versão instalada, ex. "1.0.5 (5)".
  static Future<({int code, String name})> current() async {
    final p = await PackageInfo.fromPlatform();
    return (code: int.tryParse(p.buildNumber) ?? 0, name: p.version);
  }

  /// Consulta a versão publicada; devolve dados só se for mais nova que a instalada.
  static Future<UpdateInfo?> check() async {
    final res = await http.get(Uri.parse('$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final remote = (j['versionCode'] as num?)?.toInt() ?? 0;
    final mine = (await current()).code;
    if (remote <= mine) return null;
    return UpdateInfo(remote, j['versionName'] as String? ?? '1.0.$remote', j['sha256'] as String?);
  }

  /// Baixa o APK novo e abre o instalador do Android (o usuário toca em "Atualizar").
  static Stream<OtaEvent> install(UpdateInfo u) => OtaUpdate().execute(
        apkUrl,
        destinationFilename: 'D-Libery.apk',
        sha256checksum: u.sha256,
      );
}
