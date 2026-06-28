// デモモード時に画面全体へ重ねる UI。
//  - 起動直後のミニ操作ガイド（1枚）
//  - アプリ内ブラウザ警告バナー（Instagram/LINE 等）
//  - 進行状況に応じた文脈ヒント + 「おまかせで埋める」ボタン
//
// 「おまかせ」を最初から大きく出すと、対戦表生成・得点入力を体験する前に
// 押されて結果だけ見て終わってしまうため、デモ大会の進行状況（対戦表が
// 生成されたか・何試合入力済みか）を監視して段階的に出し分ける。
//
// 大会詳細画面（巨大）には一切手を加えず、MaterialApp.builder でラップして実現する。
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  // 進行状況（デモ大会の予選1試合の状態を監視）
  StreamSubscription<QuerySnapshot>? _sub;
  String? _watchedTid;
  int _total = 0;
  int _completed = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// demoTournamentId が確定したら予選1の試合状況を監視開始。
  void _ensureListener() {
    final tid = DemoService.demoTournamentId;
    if (tid == null || tid == _watchedTid) return;
    _watchedTid = tid;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tid)
        .collection('rounds')
        .doc('round_1')
        .collection('matches')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final total = snap.docs.length;
      final completed =
          snap.docs.where((d) => d.data()['status'] == 'completed').length;
      setState(() {
        _total = total;
        _completed = completed;
      });
    });
  }

  Future<void> _runAutoFill() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await DemoService.autoFillScores();
      if (mounted) {
        setState(() => _message = '結果ができました！上の「順位表」タブをご覧ください');
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
    _ensureListener();

    final showGuide = !_guideDismissed && DemoService.demoTournamentId != null;
    final showBrowserBanner = !_browserBannerDismissed && isInAppBrowser();

    final generated = _total > 0;
    final anyCompleted = _completed > 0;
    final allCompleted = generated && _completed >= _total;

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

        // 進行状況に応じたヒント + アクション（ガイド表示中は隠す）
        if (!showGuide)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: _DemoBar(
              busy: _busy,
              message: _message,
              generated: generated,
              anyCompleted: anyCompleted,
              allCompleted: allCompleted,
              onAutoFill: _runAutoFill,
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

/// 進行状況に応じてヒント文とアクションを出し分けるバー。
class _DemoBar extends StatelessWidget {
  final bool busy;
  final String? message;
  final bool generated;
  final bool anyCompleted;
  final bool allCompleted;
  final VoidCallback onAutoFill;
  final VoidCallback onHelp;
  final VoidCallback onDismissMessage;

  const _DemoBar({
    required this.busy,
    required this.message,
    required this.generated,
    required this.anyCompleted,
    required this.allCompleted,
    required this.onAutoFill,
    required this.onHelp,
    required this.onDismissMessage,
  });

  String get _hint {
    if (!generated) {
      return '① まず「対戦表を自動生成」を押してみましょう';
    }
    if (!anyCompleted) {
      return '② 試合をタップして得点を入力（1試合でOK）';
    }
    if (!allCompleted) {
      return 'いいですね！残りは下のボタンでまとめて入力できます';
    }
    return '完成！上の「順位表」タブで結果を確認できます';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 完了メッセージ
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
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
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

          // 文脈ヒント + 使い方
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _hint,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4),
                  ),
                ),
                InkWell(
                  onTap: busy ? null : onHelp,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline,
                            size: 16, color: Colors.white70),
                        SizedBox(width: 2),
                        Text('使い方',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // アクション: 出し分け
          // - 未生成: ボタンなし（画面内の「対戦表を自動生成」へ誘導）
          // - 生成済み・入力ゼロ: 控えめなスキップリンクのみ
          // - 1試合でも入力済み: 金ボタンで「残りはおまかせ」
          // - 全完了: ボタンなし
          if (generated && !allCompleted)
            anyCompleted
                ? ElevatedButton.icon(
                    onPressed: busy ? null : onAutoFill,
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
                      busy ? '自動入力中…' : '残りはおまかせで埋める',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                : Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: busy ? null : onAutoFill,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        busy ? '処理中…' : '入力をスキップして結果を見る',
                        style: const TextStyle(fontSize: 12),
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
                    '試合をタップ → スコアを入れてスライドで確定（1試合だけでOK）'),
                _step(Icons.leaderboard, '③結果を見る',
                    '上の「順位表」タブで総合順位がリアルタイムに反映'),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          '得点入力を1試合ためしたら、残りは画面下のボタンでまとめて自動入力できます。',
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
