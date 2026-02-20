import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../services/notification_service.dart';
import '../tournament/tournament_detail_screen.dart';
import '../follow/follow_search_screen.dart';
import '../notification/notification_screen.dart';
import '../tournament/venue_search_screen.dart';
import '../tournament/tournament_management_screen.dart';
import '../recruitment/recruitment_management_screen.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';
import '../gadget/gadget_list_screen.dart';

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

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final nickname = _safeString(data['nickname']).isEmpty
              ? '未設定' : _safeString(data['nickname']);
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
          final tournamentsPlayed = _safeInt(stats['tournamentsPlayed']);
          final championships = _safeInt(stats['championships']);
          final followersCount = _safeInt(data['followersCount']);
          final followingCount = _safeInt(data['followingCount']);

          return CustomScrollView(
            slivers: [
              // ━━━ ヒーローヘッダー（YAMAP風） ━━━
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryDark, AppTheme.primaryColor, AppTheme.primaryLight],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // ── トップバー ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                          child: Row(
                            children: [
                              const Text('マイページ',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const Spacer(),
                              StreamBuilder<int>(
                                stream: NotificationService.unreadCountStream(user.uid),
                                builder: (context, notifSnap) {
                                  final unread = notifSnap.data ?? 0;
                                  return IconButton(
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                                    icon: Badge(
                                      isLabelVisible: unread > 0,
                                      label: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: AppTheme.error,
                                      child: const Icon(Icons.notifications_outlined, size: 22, color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                                icon: const Icon(Icons.settings_outlined, size: 22, color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // ── アバター + 名前 ──
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ProfileEditScreen(userData: data))),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                                ),
                                child: avatarUrl.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 40,
                                        backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                      )
                                    : CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        child: Text(
                                          nickname.isNotEmpty ? nickname[0] : '?',
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(nickname,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 6),
                        // ── タグ ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (experience.isNotEmpty)
                              _buildHeaderTag('競技歴 $experience'),
                            if (experience.isNotEmpty && area.isNotEmpty)
                              const SizedBox(width: 6),
                            if (area.isNotEmpty)
                              _buildHeaderTag(area),
                          ],
                        ),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(bio,
                                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── フォロー / フォロワー ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFollowCount(context, '$followingCount', 'フォロー', () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => FollowListScreen(
                                    userId: user.uid, title: 'フォロー中', isFollowers: false)));
                            }),
                            Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 28),
                                color: Colors.white.withValues(alpha: 0.25)),
                            _buildFollowCount(context, '$followersCount', 'フォロワー', () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => FollowListScreen(
                                    userId: user.uid, title: 'フォロワー', isFollowers: true)));
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // ━━━ ダッシュボード（スタッツ） ━━━
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildDashboardStat(Icons.star_rounded, '$totalPoints', '通算Pt', AppTheme.accentColor)),
                        Container(width: 1, height: 36, color: Colors.grey[200]),
                        Expanded(child: _buildDashboardStat(Icons.emoji_events_rounded, '$tournamentsPlayed', '大会参加', AppTheme.primaryColor)),
                        Container(width: 1, height: 36, color: Colors.grey[200]),
                        Expanded(child: _buildDashboardStat(Icons.military_tech_rounded, '$championships', '優勝', AppTheme.warning)),
                      ],
                    ),
                  ),
                ),
              ),

              // ━━━ コンテンツ ━━━
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── 友達をさがす ──
                    _buildActionCard(
                      icon: Icons.person_add_rounded,
                      title: '友達をさがす',
                      subtitle: 'QRコード・ID検索・ユーザー検索',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FollowSearchScreen())),
                    ),
                    const SizedBox(height: 20),

                    // ── 管理 ──
                    _buildSectionLabel('管理'),
                    const SizedBox(height: 8),
                    _buildMenuGroup([
                      _MenuItemData(Icons.emoji_events_outlined, '大会管理', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TournamentManagementScreen()));
                      }),
                      _MenuItemData(Icons.person_search_outlined, 'メンバー募集管理', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecruitmentManagementScreen()));
                      }),
                      _MenuItemData(Icons.location_city_outlined, '会場を登録・検索', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const VenueSearchScreen()));
                      }),
                      _MenuItemData(Icons.devices_other_outlined, 'ガジェット管理', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GadgetListScreen()));
                      }),
                    ]),
                    const SizedBox(height: 20),

                    // ── 履歴・記録 ──
                    _buildSectionLabel('履歴・記録'),
                    const SizedBox(height: 8),
                    _buildMenuGroup([
                      _MenuItemData(Icons.history_rounded, '参加大会履歴', () => _showComingSoon(context)),
                      _MenuItemData(Icons.people_outline_rounded, '対戦ヒストリー', () => _showComingSoon(context)),
                      _MenuItemData(Icons.article_outlined, '自分の投稿', () => _showComingSoon(context)),
                    ]),
                    const SizedBox(height: 20),

                    // ── その他 ──
                    _buildSectionLabel('その他'),
                    const SizedBox(height: 8),
                    _buildMenuGroup([
                      _MenuItemData(Icons.bookmark_outline_rounded, 'ブックマーク', () => _showComingSoon(context)),
                      _MenuItemData(Icons.workspace_premium_outlined, 'バッジコレクション', () => _showComingSoon(context)),
                      _MenuItemData(Icons.leaderboard_outlined, 'ランキング', () => _showComingSoon(context)),
                      _MenuItemData(Icons.save_outlined, 'テンプレート管理', () => _showComingSoon(context)),
                    ]),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── ヘッダー上のタグ ──
  Widget _buildHeaderTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }

  // ── フォロー数（ヘッダー内） ──
  Widget _buildFollowCount(
      BuildContext context, String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ── ダッシュボードスタッツ ──
  Widget _buildDashboardStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  // ── アクションカード（友達をさがす等） ──
  Widget _buildActionCard({
    required IconData icon, required String title, required String subtitle,
    required Color color, required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── セクションラベル ──
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
    );
  }

  // ── メニューグループ ──
  Widget _buildMenuGroup(List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildMenuItem(items[i].icon, items[i].title, items[i].onTap),
            if (i < items.length - 1)
              Divider(height: 1, indent: 54, color: Colors.grey[100]),
          ],
        ],
      ),
    );
  }

  // ── メニューアイテム ──
  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('この機能は準備中です'),
        backgroundColor: AppTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── メニューアイテムデータ ──
class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuItemData(this.icon, this.title, this.onTap);
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
