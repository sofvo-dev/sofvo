// デモモード時に画面全体へ重ねる UI。
//  - 起動直後のミニ操作ガイド（1枚）
//  - アプリ内ブラウザ警告バナー（Instagram/LINE 等）
//  - 「残りを自動入力して結果を見る」フローティングボタン（全セット手入力の手間を省く）
//
// 大会詳細画面（巨大）には一切手を加えず、MaterialApp.builder でラップして実現する。
import 'package:flutter/material.dart';

import '../services/in_app_browser.dart';
import 'demo_service.dart';

const Color _navy = Color(0xFF1B3A5C);
const Color _gold = Color(0xFFBFA258);

class DemoOverlay extends StatefulWidget {
  final Widget child;
  const DemoOverlay({super.key, required this.child});

  @override
  State<DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<DemoOverlay> {
  bool _guideDismissed = false;
  bool _browserBannerDismissed = false;
  bool _busy = false;
  String? _message;

  Future<void> _runAutoFill() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await DemoService.autoFillScores();
      if (mounted) {
        setState(() {
          _message = '順位表を更新しました！「順位表」タブをご覧ください';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = '自動入力に失敗しました。もう一度お試しください');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showGuide = !_guideDismissed && DemoService.demoTournamentId != null;
    final showBrowserBanner = !_browserBannerDismissed && isInAppBrowser();

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,

        // アプリ内ブラウザ警告（Instagram/LINE 等は保存領域が不安定）
        if (showBrowserBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _BrowserBanner(
              onClose: () => setState(() => _browserBannerDismissed = true),
            ),
          ),

        // 自動入力フローティングボタン（ガイド表示中は隠す）
        if (!showGuide)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _AutoFillBar(
              busy: _busy,
              message: _message,
              onTap: _runAutoFill,
              onHelp: () => setState(() => _guideDismissed = false),
              onDismissMessage: () => setState(() => _message = null),
            ),
          ),

        // 起動直後のミニ操作ガイド
        if (showGuide)
          _GuideCard(onStart: () => setState(() => _guideDismissed = true)),
      ],
    );
  }
}

class _BrowserBanner extends StatelessWidget {
  final VoidCallback onClose;
  const _BrowserBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_in_browser,
                  color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'アプリ内ブラウザでは不安定な場合があります。Safari / Chrome で開くと快適です。',
                  style: TextStyle(fontSize: 12, color: Color(0xFFBF560A)),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Color(0xFFBF560A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoFillBar extends StatelessWidget {
  final bool busy;
  final String? message;
  final VoidCallback onTap;
  final VoidCallback onHelp;
  final VoidCallback onDismissMessage;
  const _AutoFillBar({
    required this.busy,
    required this.message,
    required this.onTap,
    required this.onHelp,
    required this.onDismissMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(message!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  InkWell(
                    onTap: onDismissMessage,
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          // 使い方を再表示
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: busy ? null : onHelp,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('使い方',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _gold.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                busy ? '自動入力中…' : 'おまかせで結果まで進める',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final VoidCallback onStart;
  const _GuideCard({required this.onStart});

  Widget _step(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B6B6B),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                    children: [
                      TextSpan(text: 'Sof', style: TextStyle(color: _navy)),
                      TextSpan(text: 'vo', style: TextStyle(color: _gold)),
                      TextSpan(
                          text: ' 体験デモ',
                          style: TextStyle(
                              color: Color(0xFF1A1A1A), fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ログイン不要。3ステップでお試しください',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(height: 16),
                _step(Icons.auto_fix_high, '①対戦表をつくる',
                    'いま開いている「対戦表」タブの青いボタン「対戦表を自動生成」をタップ'),
                _step(Icons.scoreboard, '②得点を入れる',
                    '試合をタップ → スコアを入れてスライドで確定'),
                _step(Icons.leaderboard, '③結果を見る',
                    '上の「順位表」タブで総合順位がリアルタイムに反映'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: _gold),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '面倒なら下の金色のボタン「おまかせで結果まで進める」をタップ。ワンタップで結果まで自動で進みます。',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B5A2A),
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '※ 入力した内容は自動的に削除されます',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('はじめる',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
