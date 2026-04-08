import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../chat/chat_screen.dart';

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
              answer: 'トップ画面の「新規登録」から、メールアドレス・Google・Appleアカウントのいずれかで登録できます。\n\nメール登録の場合は確認メールが届きますので、メール内のリンクをクリックして認証を完了してください。',
            ),
            _FaqItem(
              question: 'パスワードを忘れました',
              answer: 'ログイン画面の「パスワードをお忘れですか？」をタップし、登録メールアドレスを入力してください。パスワードリセット用のメールが届きます。\n\nGoogle・Appleログインの場合はパスワードリセットは不要です。',
            ),
            _FaqItem(
              question: 'プロフィールを変更したい',
              answer: 'マイページ → プロフィール編集から、ニックネーム・アイコン・自己紹介・ポジション・地域などを変更できます。',
            ),
            _FaqItem(
              question: 'メールアドレスを変更したい',
              answer: '設定画面の「アカウント」セクションからメールアドレスを変更できます。\n\n※ Google・Appleログインの場合は認証メールの変更はできません。',
            ),
            _FaqItem(
              question: 'アカウントを削除したい',
              answer: '設定画面の最下部にある「アカウント削除」から手続きできます。\n\n削除すると、投稿・チャット履歴・エントリー情報などすべてのデータが削除されます。この操作は取り消せません。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('大会', [
            _FaqItem(
              question: '大会の作成方法は？',
              answer: 'マイページ → 大会管理 → 右下の「＋」ボタンから新しい大会を作成できます。\n\n大会名・日程・会場・コート数・募集チーム数・参加費・カテゴリ・ルールなどを設定します。',
            ),
            _FaqItem(
              question: '大会にエントリーするには？',
              answer: '「さがす」タブから大会を探し、大会詳細ページの「エントリーする」ボタンからエントリーできます。\n\nチーム名とメンバーを入力して送信してください。',
            ),
            _FaqItem(
              question: 'エントリーの締め切りは変更できますか？',
              answer: 'はい。大会管理 → 対象の大会 → 「大会を編集」から締切日を変更できます。',
            ),
            _FaqItem(
              question: 'エントリーをキャンセルしたい',
              answer: '大会詳細ページの自分のエントリーから「エントリー取消」ができます。\n\n※ 大会主催者にはキャンセルの通知が届きます。',
            ),
            _FaqItem(
              question: '大会のステータスとは？',
              answer: '大会には以下のステータスがあります：\n\n• 準備中：大会の設定中\n• 募集中：エントリー受付中\n• エントリー締切：募集終了\n• 開催中：大会進行中\n• 終了：大会終了\n\n主催者は大会管理画面からステータスを変更できます。',
            ),
            _FaqItem(
              question: '大会をキャンセルしたい',
              answer: '大会管理画面から大会を削除できます。\n\n※ エントリー済みの参加者がいる場合は、事前にお知らせを送信することをおすすめします。',
            ),
            _FaqItem(
              question: '対戦表・スコアの入力方法は？',
              answer: '大会詳細 → 主催者メニュー → 対戦表管理から、予選リーグや決勝トーナメントの対戦表を作成・スコア入力できます。\n\nCSVインポートにも対応しています。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('メンバー募集', [
            _FaqItem(
              question: 'メンバー募集の作成方法は？',
              answer: '「さがす」タブ → メンバー募集タブ → 右下の「＋」ボタンから作成できます。\n\n募集内容・日時・場所・レベル・人数などを入力してください。',
            ),
            _FaqItem(
              question: '募集に応募するには？',
              answer: '募集詳細ページの「応募する」ボタンから応募できます。主催者が承認すると参加が確定します。',
            ),
            _FaqItem(
              question: '募集を締め切りたい',
              answer: '募集管理画面から「締切」に変更できます。締切後は新規応募を受け付けません。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('チャット', [
            _FaqItem(
              question: 'チャットの始め方は？',
              answer: '相手のプロフィールページから「メッセージを送る」でDMを開始できます。\n\nまた、大会の主催者や参加者にもチャットを送れます。',
            ),
            _FaqItem(
              question: 'グループチャットの作成方法は？',
              answer: 'チャットタブの右上の「＋」ボタンからグループを作成できます。\n\nフォロー中のユーザーをメンバーに追加できます。',
            ),
            _FaqItem(
              question: 'メッセージを削除できますか？',
              answer: '自分が送信したメッセージを長押しすると削除できます。\n\n※ 相手側の画面からもメッセージが非表示になります。',
            ),
            _FaqItem(
              question: 'チャットを削除・退出したい',
              answer: 'チャット一覧で対象のチャットを左にスワイプすると、削除（DM）または退出（グループ）ができます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('フォロー・つながり', [
            _FaqItem(
              question: 'フォローするには？',
              answer: '相手のプロフィールページの「フォロー」ボタンをタップするとフォローできます。\n\nフォローすると、相手の投稿がタイムラインに表示されます。',
            ),
            _FaqItem(
              question: 'フォロワー・フォロー中の確認方法は？',
              answer: 'マイページのフォロー数・フォロワー数をタップすると一覧が表示されます。',
            ),
            _FaqItem(
              question: 'ユーザーをブロックしたい',
              answer: '相手のプロフィール → 右上のメニュー → 「ブロック」から設定できます。\n\nブロックすると、相手からのチャット・フォロー・応募ができなくなります。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('通知', [
            _FaqItem(
              question: '通知が届きません',
              answer: '以下を確認してください：\n\n1. 端末の設定 → Sofvo → 通知を「許可」\n2. アプリ内の設定 → 通知設定がONになっているか確認\n3. 電波状況を確認\n\nそれでも届かない場合は、一度ログアウトしてログインし直してみてください。',
            ),
            _FaqItem(
              question: '通知の種類は？',
              answer: '以下の通知をお知らせします：\n\n• チャットの新着メッセージ\n• 大会の更新情報（ステータス変更、お知らせ等）\n• フォローの通知\n• エントリー関連の通知\n\n設定画面から各通知のON/OFFを切り替えられます。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('投稿・タイムライン', [
            _FaqItem(
              question: '投稿の作成方法は？',
              answer: 'ホーム画面の右下のペンアイコンをタップすると投稿を作成できます。\n\nテキストと画像を投稿できます。',
            ),
            _FaqItem(
              question: '投稿を削除したい',
              answer: '自分の投稿の右上「…」メニューから削除できます。',
            ),
            _FaqItem(
              question: '不適切な投稿を報告したい',
              answer: '投稿の右上「…」メニューから「報告」を選択してください。運営が確認し対応します。',
            ),
          ]),
          const SizedBox(height: 16),
          _buildCategory('その他', [
            _FaqItem(
              question: 'アプリが重い・動作が遅い',
              answer: '以下をお試しください：\n\n1. アプリを再起動する\n2. 端末を再起動する\n3. アプリを最新バージョンに更新する\n4. Wi-Fi環境で使用する',
            ),
            _FaqItem(
              question: 'Web版とアプリ版の違いは？',
              answer: '基本機能は同じです。アプリ版ではプッシュ通知が届くため、リアルタイムで情報を受け取れます。\n\nApp Store / Google Play からインストールできます。',
            ),
            _FaqItem(
              question: '不具合を報告したい',
              answer: '設定画面の「フィードバック」からご報告ください。\n\nまたは公式アカウント(@sofvo)にDMでもお問い合わせいただけます。',
            ),
            _FaqItem(
              question: '利用規約・プライバシーポリシーはどこで確認できますか？',
              answer: '設定画面の最下部に「利用規約」「プライバシーポリシー」のリンクがあります。',
            ),
          ]),
          const SizedBox(height: 24),
          _buildContactSection(context),
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

  Widget _buildContactSection(BuildContext context) {
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
            '解決しない場合は、公式アカウントに\nお気軽にお問い合わせください。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                const officialUid = 'zlBy8aWUlCYjyy0NUU9HidrQu983';
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ChatScreen(otherUserId: officialUid, otherUserName: '【公式】Sofvo'),
                ));
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('公式アカウントにチャットする'),
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
