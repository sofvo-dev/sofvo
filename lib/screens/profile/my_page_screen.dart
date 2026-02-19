import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../services/bookmark_notification_service.dart';
import '../tournament/tournament_detail_screen.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../follow/follow_search_screen.dart';
import '../tournament/venue_search_screen.dart';
import '../tournament/tournament_management_screen.dart';
import '../recruitment/recruitment_management_screen.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  String _safeString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value.values.join(' ');
    return value?.toString() ?? '';
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('ログインしてください'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                final data =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};

                final nickname = _safeString(data['nickname']).isEmpty
                    ? '未設定'
                    : _safeString(data['nickname']);
                final experience = _safeString(data['experience']);
                final avatarUrl = _safeString(data['avatarUrl']);
                final rawArea = data['area'];
                final area = rawArea is String
                    ? rawArea
                    : rawArea is Map
                        ? '${rawArea['prefecture'] ?? ''}${rawArea['city'] ?? ''}'
                        : '';
                final bio = _safeString(data['bio']);
                final totalPoints = _safeInt(data['totalPoints']);
                final stats = data['stats'] is Map<String, dynamic>
                    ? data['stats'] as Map<String, dynamic>
                    : <String, dynamic>{};
                final tournamentsPlayed =
                    _safeInt(stats['tournamentsPlayed']);
                final championships = _safeInt(stats['championships']);
                final followersCount = _safeInt(data['followersCount']);
                final followingCount = _safeInt(data['followingCount']);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── プロフィールカード ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // アバター表示
                              avatarUrl.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 36,
                                      backgroundImage:
                                          NetworkImage(avatarUrl),
                                      backgroundColor: AppTheme
                                          .primaryColor
                                          .withValues(alpha: 0.12),
                                    )
                                  : CircleAvatar(
                                      radius: 36,
                                      backgroundColor: AppTheme
                                          .primaryColor
                                          .withValues(alpha: 0.12),
                                      child: Text(
                                        nickname.isNotEmpty
                                            ? nickname[0]
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nickname,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (experience.isNotEmpty)
                                          _buildTag('競技歴 $experience',
                                              AppTheme.primaryColor),
                                        if (area.isNotEmpty)
                                          _buildTag(area,
                                              AppTheme.textSecondary),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileEditScreen(
                                              userData: data),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('編集',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              _buildFollowCount(
                                context, '$followingCount', 'フォロー',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FollowListScreen(userId: FirebaseAuth.instance.currentUser!.uid, title: 'フォロー中', isFollowers: false,
                                              ),
                                    ),
                                  );
                                },
                              ),
                              Container(
                                width: 1,
                                height: 24,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 24),
                                color: Colors.grey[300],
                              ),
                              _buildFollowCount(
                                context, '$followersCount', 'フォロワー',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FollowListScreen(userId: FirebaseAuth.instance.currentUser!.uid, title: 'フォロワー', isFollowers: true,
                                              ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── ステータスカード ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(Icons.star, '通算ポイント',
                              '$totalPoints', AppTheme.accentColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                              Icons.emoji_events, '大会参加',
                              '$tournamentsPlayed', AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(Icons.military_tech,
                              '優勝', '$championships', AppTheme.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 友達をさがす ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add,
                              color: AppTheme.primaryColor, size: 22),
                        ),
                        title: const Text('友達をさがす',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary)),
                        subtitle: Text('QRコード・ID検索・ユーザー検索',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                        trailing: Icon(Icons.chevron_right,
                            color: Colors.grey[400], size: 22),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const FollowSearchScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 管理メニュー ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                              Icons.emoji_events_outlined, '大会管理', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const TournamentManagementScreen()),
                            );
                          }),
                          _buildMenuDivider(),
                          _buildMenuItem(
                              Icons.person_search_outlined,
                              'メンバー募集管理', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const RecruitmentManagementScreen()),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 履歴メニュー ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                              Icons.history, '参加大会履歴', () {}),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.people_outline,
                              '対戦ヒストリー', () {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── その他メニュー ──
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text("その他", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(Icons.article_outlined,
                              '自分の投稿', () {}),
                          _buildMenuDivider(),
                          _buildMenuItem(
                              Icons.workspace_premium_outlined,
                              'バッジコレクション', () {}),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.leaderboard_outlined,
                              'ランキング', () {}),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.save_outlined,
                              'テンプレート管理', () {}),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.location_city, '会場を登録・検索', () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const VenueSearchScreen()));
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildFollowCount(
      BuildContext context, String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15, color: AppTheme.textPrimary)),
      trailing:
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
      onTap: onTap,
    );
  }

  Widget _buildMenuDivider() {
    return Divider(height: 1, indent: 56, color: Colors.grey[100]);
  }

  void _showLogoutDialog(BuildContext context) {
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
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// プロフィール編集画面（アバターアップロード対応）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileEditScreen({super.key, required this.userData});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nicknameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _idCtrl;
  String _selectedExperience = '1年未満';
  String _selectedArea = '東京都';
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String _avatarUrl = '';

  final _picker = ImagePicker();

  final _experiences = ['1年未満', '1〜3年', '3〜5年', '5〜10年', '10年以上'];
  final _areas = [
    '北海道', '東北', '東京都', '神奈川県', '千葉県', '埼玉県',
    '関東（その他）', '中部', '関西', '中国', '四国', '九州', '沖縄',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.userData;
    _nicknameCtrl = TextEditingController(text: _str(d['nickname']));
    _bioCtrl = TextEditingController(text: _str(d['bio']));
    _idCtrl = TextEditingController(text: _str(d['searchId']));
    _avatarUrl = _str(d['avatarUrl']);

    final rawExp = _str(d['experience']);
    _selectedExperience =
        _experiences.contains(rawExp) ? rawExp : '1年未満';

    final rawArea = d['area'];
    String areaStr = '';
    if (rawArea is String) {
      areaStr = rawArea;
    } else if (rawArea is Map) {
      areaStr = '${rawArea['prefecture'] ?? ''}';
    }
    if (_areas.contains(areaStr)) {
      _selectedArea = areaStr;
    } else {
      _selectedArea = _areas.firstWhere(
        (a) => areaStr.contains(a) || a.contains(areaStr),
        orElse: () => '東京都',
      );
    }
  }

  String _str(dynamic v) => v is String ? v : (v?.toString() ?? '');

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('$uid.$ext');

      final metadata = SettableMetadata(
        contentType: 'image/$ext',
      );

      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      // Firestore にも avatarUrl を更新
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatarUrl': downloadUrl});

      setState(() {
        _avatarUrl = downloadUrl;
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アバターを更新しました'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アバターのアップロードに失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── アバター ──
          Center(
            child: GestureDetector(
              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
              child: Stack(
                children: [
                  _isUploadingAvatar
                      ? CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.primaryColor
                              .withValues(alpha: 0.12),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : _avatarUrl.isNotEmpty
                          ? CircleAvatar(
                              radius: 48,
                              backgroundImage:
                                  NetworkImage(_avatarUrl),
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                            )
                          : CircleAvatar(
                              radius: 48,
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                              child: Text(
                                _nicknameCtrl.text.isNotEmpty
                                    ? _nicknameCtrl.text[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor),
                              ),
                            ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'タップして写真を変更',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('ニックネーム'),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameCtrl,
            maxLength: 15,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration('ニックネームを入力'),
          ),
          const SizedBox(height: 8),
          _buildSectionLabel('ユーザーID'),
          const SizedBox(height: 8),
          TextField(
            controller: _idCtrl,
            maxLength: 20,
            decoration: _inputDecoration('@から始まるID'),
          ),
          const SizedBox(height: 8),
          _buildSectionLabel('競技歴'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _experiences.map((exp) {
              final sel = _selectedExperience == exp;
              return ChoiceChip(
                label: Text(exp),
                selected: sel,
                onSelected: (s) {
                  if (s) setState(() => _selectedExperience = exp);
                },
                selectedColor:
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: sel
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight:
                      sel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('エリア'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: DropdownButton<String>(
              value: _selectedArea,
              isExpanded: true,
              underline: const SizedBox(),
              items: _areas
                  .map((a) =>
                      DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedArea = v);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('自己紹介'),
          const SizedBox(height: 8),
          TextField(
            controller: _bioCtrl,
            maxLines: 4,
            maxLength: 200,
            decoration: _inputDecoration('自己紹介を入力')
                .copyWith(alignLabelWithHint: true),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: const Text('保存する',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textHint),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppTheme.primaryColor, width: 2)),
    );
  }

  Future<void> _saveProfile() async {
    if (_nicknameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ニックネームを入力してください')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          'nickname': _nicknameCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'searchId': _idCtrl.text.trim(),
          'experience': _selectedExperience,
          'area': _selectedArea,
          'avatarUrl': _avatarUrl,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('プロフィールを更新しました！'),
            backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
