import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';
import '../home/create_post_screen.dart';
import 'venue_search_screen.dart';
import '../gadget/gadget_register_screen.dart';
import '../follow/follow_search_screen.dart';

/// 大会終了後のアクション促進画面
/// Step1: ふりかえり投稿（テンプレート選択）
/// Step2: 投稿完了後 → ついでにもう1つ
class PostEventActionScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String? result; // 例: '優勝', '準優勝', '3位', 'ベスト8'

  const PostEventActionScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.result,
  });

  @override
  State<PostEventActionScreen> createState() => _PostEventActionScreenState();
}

class _PostEventActionScreenState extends State<PostEventActionScreen> {
  bool _posted = false; // 投稿完了したか

  List<String> get _templates {
    final result = widget.result;
    final hasResult = result != null && result.isNotEmpty;
    return [
      if (hasResult && result == '優勝') '優勝できました！チームに感謝！',
      if (hasResult && result != '優勝') '悔しい！次こそリベンジ！',
      '楽しかった！次も参加したい',
      '初参加でしたが楽しめました！',
    ];
  }

  Future<void> _openPostWithTemplate(String template) async {
    final text = '${widget.tournamentName}\n'
        '${widget.result != null && widget.result!.isNotEmpty ? '結果: ${widget.result}\n' : ''}'
        '\n$template';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          tournamentId: widget.tournamentId,
          tournamentName: widget.tournamentName,
          initialText: text,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _posted = true);
    }
  }

  Future<void> _openFreePost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          tournamentId: widget.tournamentId,
          tournamentName: widget.tournamentName,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() => _posted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _posted ? _buildFollowUpScreen() : _buildReviewScreen();
  }

  // ━━━ Step1: ふりかえり投稿画面 ━━━
  Widget _buildReviewScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ヘッダー
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, size: 32, color: AppTheme.accentColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'お疲れさまでした！',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.tournamentName,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (widget.result != null && widget.result!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '結果: ${widget.result}',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 説明
              const Text(
                '今日の感想を残しませんか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // テンプレート選択肢
              Expanded(
                child: ListView(
                  children: [
                    ..._templates.map((t) => _templateButton(t)),
                    _templateButton('自分の言葉で書く', icon: Icons.edit, isFreeForm: true),
                  ],
                ),
              ),

              // あとで
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'あとで',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateButton(String text, {IconData? icon, bool isFreeForm = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isFreeForm
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => isFreeForm ? _openFreePost() : _openPostWithTemplate(text),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFreeForm
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon ?? Icons.chat_bubble_outline,
                  size: 20,
                  color: isFreeForm ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isFreeForm ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ━━━ Step2: ついでにもう1つ画面 ━━━
  Widget _buildFollowUpScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // 投稿完了メッセージ
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 32, color: AppTheme.success),
              ),
              const SizedBox(height: 16),
              const Text(
                '投稿しました！',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 32),

              // ついでにもう1つ
              const Text(
                'ついでにもう1つ\nやってみませんか？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    _followUpAction(
                      icon: Icons.apartment,
                      title: '会場の情報を登録',
                      subtitle: '床・ポール・設備の記録',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VenueSearchScreen()),
                        );
                      },
                    ),
                    _followUpAction(
                      icon: Icons.sports_handball,
                      title: '使った道具を登録',
                      subtitle: 'シューズ・サポーター等の記録',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GadgetRegisterScreen()),
                        );
                      },
                    ),
                    _followUpAction(
                      icon: Icons.people,
                      title: '参加者をフォロー',
                      subtitle: '今日の対戦相手とつながる',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FollowSearchScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // おしまい
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('おしまい', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _followUpAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
