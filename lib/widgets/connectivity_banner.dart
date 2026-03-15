import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_theme.dart';

/// アプリ全体で使えるオフライン状態バナー
/// MainTabScreen の body を wrap して使う
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    // 定期的にネットワーク状態をチェック（30秒ごと）
    _checkConnectivity();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    // Web版ではnavigator.onLineを使用、それ以外はFirestoreの接続状態で判定
    if (kIsWeb) {
      // Web: JSのnavigator.onLineは使えないので、Firestoreのキャッシュヒットで判定
      // 簡易的にはスキップ（Web版は常にオンライン扱い）
      return;
    }
    // モバイル: 簡易的なオフライン検出
    // connectivity_plusパッケージなしで実装する場合は、
    // Firestoreのメタデータから判定
    // ここではFirestoreの enableNetwork/disableNetwork のコールバックは使わず、
    // snapshotのmetadata.isFromCacheで判定するアプローチを取る
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // オフラインバナー
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.warning,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'オフラインです。一部の機能が制限されます。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _checkConnectivity,
                    child: const Icon(Icons.refresh, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// StreamBuilder等でFirestoreのキャッシュ状態を検知するヘルパー
/// snapshot.metadata.isFromCache が true の場合にオフラインとみなす
class FirestoreOfflineIndicator extends StatelessWidget {
  final bool isFromCache;
  const FirestoreOfflineIndicator({super.key, required this.isFromCache});

  @override
  Widget build(BuildContext context) {
    if (!isFromCache) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: AppTheme.warning),
          const SizedBox(width: 6),
          Text(
            'キャッシュデータを表示中',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
