import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('よくある質問'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory('アカウント', [
            _FaqItem(
              question: 'アカウントの作成方法は？',
              answer: 'メール、Google、Appleアカウントで登録できます。',
            ),
            _FaqItem(
              question: 'パスワードを忘れました',
              answer: 'ログイン画面の「パスワードを忘れた方」からリセットできます。',
            ),
            _FaqItem(
              question: 'アカウントを削除したい',
              answer: '設定画面の「アカウント削除」から手続きできます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('大会', [
            _FaqItem(
              question: '大会の作成方法は？',
              answer: 'マイページ→大会管理→新規作成から作成できます。',
            ),
            _FaqItem(
              question: 'エントリーの締め切りは変更できますか？',
              answer: '大会管理画面から変更可能です。',
            ),
            _FaqItem(
              question: '大会をキャンセルしたい',
              answer: '大会管理画面から大会を削除できます。参加者には通知されます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('メンバー募集', [
            _FaqItem(
              question: 'メンバー募集の作成方法は？',
              answer: 'さがす画面のメンバー募集タブから作成できます。',
            ),
            _FaqItem(
              question: '募集を締め切りたい',
              answer: '募集詳細画面から締め切り・削除ができます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('チャット', [
            _FaqItem(
              question: 'グループチャットの作成方法は？',
              answer: 'チャットタブの＋ボタンからグループを作成できます。',
            ),
            _FaqItem(
              question: 'メッセージを削除できますか？',
              answer: '自分のメッセージを長押しで削除できます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('その他', [
            _FaqItem(
              question: '通知が届きません',
              answer: '端末の設定でSofvoの通知を許可してください。',
            ),
            _FaqItem(
              question: '不具合を報告したい',
              answer: '公式アカウント(@sofvo)にお問い合わせください。',
            ),
          ]),
          const SizedBox(height: 24),
          _buildContactSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategory(String title, List<_FaqItem> items) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                if (index > 0)
                  Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey[100]),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: Icon(Icons.help_outline, color: AppTheme.primaryColor, size: 20),
                  title: Text(
                    item.question,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.answer,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent, size: 40, color: AppTheme.primaryColor),
          const SizedBox(height: 12),
          const Text(
            'お問い合わせ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '解決しない場合は、公式アカウント(@sofvo)に\nお気軽にお問い合わせください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
