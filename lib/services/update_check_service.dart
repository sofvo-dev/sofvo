import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

enum UpdateStatus { none, optional, force }

class UpdateCheckResult {
  final UpdateStatus status;
  final String? latestVersion;
  final String? updateMessage;

  const UpdateCheckResult({
    this.status = UpdateStatus.none,
    this.latestVersion,
    this.updateMessage,
  });
}

class UpdateCheckService {
  static Future<UpdateCheckResult> check() async {
    // Web版はストア更新不要
    if (kIsWeb) return const UpdateCheckResult();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();

      if (!doc.exists) return const UpdateCheckResult();

      final data = doc.data()!;
      final minVersion = data['minVersion'] as String?;
      final latestVersion = data['latestVersion'] as String?;
      final updateMessage = data['updateMessage'] as String?;

      if (minVersion == null && latestVersion == null) {
        return const UpdateCheckResult();
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.0.3"

      // 最低バージョンを下回る → 強制アップデート
      if (minVersion != null && _compareVersions(currentVersion, minVersion) < 0) {
        return UpdateCheckResult(
          status: UpdateStatus.force,
          latestVersion: latestVersion ?? minVersion,
          updateMessage: updateMessage,
        );
      }

      // 最新バージョンより古い → 任意アップデート
      if (latestVersion != null && _compareVersions(currentVersion, latestVersion) < 0) {
        return UpdateCheckResult(
          status: UpdateStatus.optional,
          latestVersion: latestVersion,
          updateMessage: updateMessage,
        );
      }

      return const UpdateCheckResult();
    } catch (e) {
      // チェック失敗時はスキップ（アプリ起動を妨げない）
      return const UpdateCheckResult();
    }
  }

  /// バージョン比較: a < b → 負, a == b → 0, a > b → 正
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (int i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}
