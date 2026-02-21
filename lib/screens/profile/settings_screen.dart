import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotification = true;
  bool _emailNotification = false;
  bool _matchNotification = true;
  bool _tournamentNotification = true;
  bool _followNotification = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      final settings =
          doc.data()?['notificationSettings'] as Map<String, dynamic>?;
      if (settings != null && mounted) {
        setState(() {
          _pushNotification = settings['push'] ?? true;
          _emailNotification = settings['email'] ?? false;
          _tournamentNotification = settings['tournament'] ?? true;
          _followNotification = settings['follow'] ?? true;
          _matchNotification = settings['match'] ?? true;
        });
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationSettings': {
        'push': _pushNotification,
        'email': _emailNotification,
        'tournament': _tournamentNotification,
        'follow': _followNotification,
        'match': _matchNotification,
      },
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── アカウント情報 ──
          _buildSectionHeader('アカウント'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  Icons.email_outlined,
                  'メールアドレス',
                  user?.email ?? '未設定',
                ),
                _buildDivider(),
                _buildInfoTile(
                  Icons.badge_outlined,
                  'ユーザーID',
                  user?.uid.substring(0, 12) ?? '---',
                ),
                _buildDivider(),
                ListTile(
                  leading: Icon(Icons.lock_outline,
                      color: AppTheme.primaryColor, size: 22),
                  title: const Text('パスワード変更',
                      style: TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right,
                      color: Colors.grey[400], size: 22),
                  onTap: () => _showChangePasswordDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 通知設定 ──
          _buildSectionHeader('通知設定'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  Icons.notifications_outlined,
                  'プッシュ通知',
                  'アプリ内の通知を受け取る',
                  _pushNotification,
                  (v) {
                    setState(() => _pushNotification = v);
                    _saveNotificationSettings();
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  Icons.mail_outline,
                  'メール通知',
                  '重要なお知らせをメールで受け取る',
                  _emailNotification,
                  (v) {
                    setState(() => _emailNotification = v);
                    _saveNotificationSettings();
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  Icons.sports_volleyball_outlined,
                  '大会通知',
                  '大会の更新・リマインダー',
                  _tournamentNotification,
                  (v) {
                    setState(() => _tournamentNotification = v);
                    _saveNotificationSettings();
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  Icons.people_outline,
                  'フォロー通知',
                  'フォロー・フォロワーの更新',
                  _followNotification,
                  (v) {
                    setState(() => _followNotification = v);
                    _saveNotificationSettings();
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  Icons.sync_alt,
                  'マッチング通知',
                  'メンバー募集のマッチング結果',
                  _matchNotification,
                  (v) {
                    setState(() => _matchNotification = v);
                    _saveNotificationSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── アプリ情報 ──
          _buildSectionHeader('アプリ情報'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  Icons.info_outline,
                  'バージョン',
                  '1.0.0',
                ),
                _buildDivider(),
                ListTile(
                  leading: Icon(Icons.description_outlined,
                      color: AppTheme.primaryColor, size: 22),
                  title: const Text('利用規約',
                      style: TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.open_in_new,
                      color: Colors.grey[400], size: 18),
                  onTap: () => _openUrl('https://sofvo.com/terms.html'),
                ),
                _buildDivider(),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined,
                      color: AppTheme.primaryColor, size: 22),
                  title: const Text('プライバシーポリシー',
                      style: TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.open_in_new,
                      color: Colors.grey[400], size: 18),
                  onTap: () => _openUrl('https://sofvo.com/privacy.html'),
                ),
                _buildDivider(),
                ListTile(
                  leading: Icon(Icons.help_outline,
                      color: AppTheme.primaryColor, size: 22),
                  title: const Text('ヘルプ・お問い合わせ',
                      style: TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.open_in_new,
                      color: Colors.grey[400], size: 18),
                  onTap: () => _openUrl('https://sofvo.com/contact.html'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 危険ゾーン ──
          _buildSectionHeader('アカウント操作'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout,
                      color: AppTheme.error, size: 22),
                  title: const Text('ログアウト',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500)),
                  onTap: () => _showLogoutDialog(),
                ),
                _buildDivider(),
                ListTile(
                  leading: Icon(Icons.delete_forever,
                      color: AppTheme.error, size: 22),
                  title: const Text('アカウント削除',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500)),
                  onTap: () => _showDeleteAccountDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title:
          Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 56, color: Colors.grey[100]);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ページを開けませんでした')),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('パスワード変更',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '現在のパスワード',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '新しいパスワード',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '新しいパスワード（確認）',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (currentPwCtrl.text.isEmpty || newPwCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('すべての項目を入力してください'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              if (newPwCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('新しいパスワードは6文字以上にしてください'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              if (newPwCtrl.text != confirmPwCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('新しいパスワードが一致しません'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              try {
                await AuthService().changePassword(
                  currentPwCtrl.text,
                  newPwCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('パスワードを変更しました'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  String message = 'パスワードの変更に失敗しました';
                  if (e.toString().contains('wrong-password') ||
                      e.toString().contains('invalid-credential')) {
                    message = '現在のパスワードが正しくありません';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 40)),
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('ログアウト',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('アカウント削除',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'アカウントを完全に削除しますか？\n\n'
              '・すべての投稿が削除されます\n'
              '・チーム情報が削除されます\n'
              '・この操作は取り消せません',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '確認のためパスワードを入力',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('パスワードを入力してください'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              try {
                await AuthService().deleteAccount(passwordCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  String message = 'アカウント削除に失敗しました';
                  if (e.toString().contains('wrong-password') ||
                      e.toString().contains('invalid-credential')) {
                    message = 'パスワードが正しくありません';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }
}
