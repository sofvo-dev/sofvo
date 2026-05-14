import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';

/// 会場掲示のチェックイン用URL（`https://sofvo.com/app?checkin=大会ID`）を参加者がスキャンする画面。
/// 主催者がチームQRを読み取るフローは使わない。
class TournamentCheckinScanScreen extends StatefulWidget {
  /// この大会詳細から開いたときのみ指定。別大会のQRは拒否する。
  final String? expectedTournamentId;

  const TournamentCheckinScanScreen({super.key, this.expectedTournamentId});

  /// QRの生データから大会IDを取り出す。チェックイン用URLでない場合は null。
  static String? parseCheckInTournamentId(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return null;
    }

    // クエリに checkin が無い場合でも、文字列内に埋め込まれていれば拾う
    String? fromQuery = uri.queryParameters['checkin'];
    if (fromQuery == null || fromQuery.isEmpty) {
      final m = RegExp(r'[?&]checkin=([^&\s#]+)').firstMatch(s);
      if (m != null) {
        fromQuery = Uri.decodeComponent(m.group(1)!);
      }
    }
    if (fromQuery == null || fromQuery.isEmpty) return null;

    final host = uri.host.toLowerCase();
    if (host == 'sofvo.com' || host == 'www.sofvo.com') {
      return fromQuery;
    }
    // ホスト無しの相対URL等では query だけマッチした場合は許可
    if (uri.host.isEmpty && fromQuery.isNotEmpty) return fromQuery;

    return null;
  }

  @override
  State<TournamentCheckinScanScreen> createState() => _TournamentCheckinScanScreenState();
}

class _TournamentCheckinScanScreenState extends State<TournamentCheckinScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handledSuccess = false;
  bool _errorThrottle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCode(String raw) {
    if (_handledSuccess || _errorThrottle) return;
    final tid = TournamentCheckinScanScreen.parseCheckInTournamentId(raw);
    if (tid == null || tid.isEmpty) {
      if (!mounted) return;
      setState(() => _errorThrottle = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('チェックイン用のQRコードではありません。\n会場に掲示されている大会QRをスキャンしてください。'),
          backgroundColor: AppTheme.warning,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _errorThrottle = false);
      });
      return;
    }
    final expected = widget.expectedTournamentId;
    if (expected != null && expected.isNotEmpty && tid != expected) {
      if (!mounted) return;
      setState(() => _errorThrottle = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('別の大会のQRコードです。この大会の掲示QRをスキャンしてください。'),
          backgroundColor: AppTheme.warning,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _errorThrottle = false);
      });
      return;
    }
    setState(() => _handledSuccess = true);
    Navigator.pop(context, tid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('大会QRをスキャン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handledSuccess || _errorThrottle) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;
              _onCode(raw);
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 56,
            left: 16,
            right: 16,
            child: Text(
              '会場に掲示されている大会のQRコードを枠内に合わせてください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
