import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/invite_service.dart';

/// 招待コードを発行して LINE 共有・コピーできるボトムシート。
///
/// 友達紹介・チーム招待・大会招待で共用する。発行されたコードと招待リンクを
/// 表示し、LINE 送信／コピーを提供する。[teamId] / [tournamentId] を渡すと
/// 引き換え時にチーム参加・大会誘導まで繋がる。
Future<void> showInviteShareSheet(
  BuildContext context, {
  String? teamId,
  String? tournamentId,
  String? teamName,
  String? tournamentName,
  String title = 'メンバーを招待',
  String description = '招待リンクとコードを送ると、相手が登録するだけで自動で友達になります。',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _InviteShareSheet(
      teamId: teamId,
      tournamentId: tournamentId,
      teamName: teamName,
      tournamentName: tournamentName,
      title: title,
      description: description,
    ),
  );
}

class _InviteShareSheet extends StatefulWidget {
  final String? teamId;
  final String? tournamentId;
  final String? teamName;
  final String? tournamentName;
  final String title;
  final String description;

  const _InviteShareSheet({
    this.teamId,
    this.tournamentId,
    this.teamName,
    this.tournamentName,
    required this.title,
    required this.description,
  });

  @override
  State<_InviteShareSheet> createState() => _InviteShareSheetState();
}

class _InviteShareSheetState extends State<_InviteShareSheet> {
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _issue();
  }

  Future<void> _issue() async {
    try {
      final code = await InviteService.createInvite(
        teamId: widget.teamId,
        tournamentId: widget.tournamentId,
      );
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = '招待コードの発行に失敗しました');
    }
  }

  String get _shareText => InviteService.shareText(
        code: _code!,
        teamName: widget.teamName,
        tournamentName: widget.tournamentName,
      );

  Future<void> _shareToLine() async {
    final text = Uri.encodeComponent(_shareText);
    final uri = Uri.parse('https://line.me/R/share?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('招待メッセージをコピーしました'), backgroundColor: AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _issue();
                    },
                    child: const Text('もう一度試す'),
                  ),
                ]),
              )
            else if (_code == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            else ...[
              // 招待コード表示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  const Text('招待コード', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _code!,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _option(
                  icon: Icons.chat_bubble,
                  label: 'LINEで送る',
                  color: const Color(0xFF06C755),
                  onTap: _shareToLine,
                ),
                _option(
                  icon: Icons.copy,
                  label: 'コピー',
                  color: AppTheme.primaryColor,
                  onTap: _copy,
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
