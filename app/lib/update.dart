import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

const _repo = 'begolo12/owner-valuation';

/// Versi terbaru diambil dari GitHub Releases (diisi oleh workflow CI).
class UpdateInfo {
  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    required this.notes,
    required this.pageUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String notes;
  final String pageUrl;

  bool get hasUpdate => _compare(latestVersion, currentVersion) > 0;
  bool get hasApk => apkUrl.isNotEmpty;

  static int _compare(String a, String b) {
    final pa = a.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

/// Cek rilis terbaru. Null kalau belum ada rilis / offline.
Future<UpdateInfo?> checkUpdate() async {
  final info = await PackageInfo.fromPlatform();
  final data = await Api.i.releaseLatest(_repo);
  if (data == null) return null;
  final tag = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
  final assets = (data['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
  final apks = assets.where((a) => (a['name'] as String? ?? '').endsWith('.apk')).toList();
  return UpdateInfo(
    currentVersion: '${info.version}+${info.buildNumber}',
    latestVersion: tag,
    apkUrl: apks.isEmpty ? '' : apks.first['browser_download_url'] as String,
    notes: data['body'] as String? ?? '',
    pageUrl: data['html_url'] as String? ?? 'https://github.com/$_repo/releases/latest',
  );
}

/// Unduh APK lalu buka installer Android. Di luar Android, buka halaman rilis.
Future<String> downloadAndInstall(UpdateInfo info, void Function(double) onProgress) async {
  if (!Platform.isAndroid || !info.hasApk) {
    await launchUrl(Uri.parse(info.pageUrl), mode: LaunchMode.externalApplication);
    return 'Membuka halaman rilis di browser';
  }

  final dir = await getTemporaryDirectory();
  final target = File('${dir.path}/owner-valuation-${info.latestVersion}.apk');
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(Uri.parse(info.apkUrl))).close();
    if (res.statusCode != 200) throw Exception('Unduhan gagal (${res.statusCode})');
    final total = res.contentLength;
    final sink = target.openWrite();
    var received = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();
  } finally {
    client.close();
  }

  final result = await OpenFilex.open(target.path, type: 'application/vnd.android.package-archive');
  if (result.type != ResultType.done) {
    throw Exception(result.message.isEmpty ? 'Installer tidak bisa dibuka' : result.message);
  }
  return 'Installer dibuka. Ikuti langkah pemasangan.';
}
