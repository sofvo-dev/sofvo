import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../config/app_theme.dart';
import '../../services/bookmark_notification_service.dart';
import '../../services/notification_service.dart';
import '../tournament/tournament_detail_screen.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../follow/follow_search_screen.dart';
import '../notification/notification_screen.dart';
import '../tournament/venue_search_screen.dart';
import '../tournament/tournament_management_screen.dart';
import '../recruitment/recruitment_management_screen.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';
import '../ranking/ranking_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  List<Map<String, dynamic>> _tournamentHistory = [];
  List<Map<String, dynamic>> _gadgets = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournamentHistory();
    _loadGadgets();
  }

  Future<void> _loadTournamentHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final tournSnap =
        await FirebaseFirestore.instance.collection('tournaments').get();
    final history = <Map<String, dynamic>>[];

    for (final doc in tournSnap.docs) {
      final data = doc.data();
      final isOrganizer = data['organizerId'] == uid;
      final entriesSnap = await doc.reference
          .collection('entries')
          .where('enteredBy', isEqualTo: uid)
          .limit(1)
          .get();
      final isEntered = entriesSnap.docs.isNotEmpty;
      if (!isOrganizer && !isEntered) continue;

      final status = data['status'] ?? '準備中';
      if (status != '終了') continue;

      history.add({
        ...data,
        'id': doc.id,
        'teamName': isEntered
            ? (entriesSnap.docs.first.data()['teamName'] ?? '')
            : '主催者',
        'isOrganizer': isOrganizer,
      });
    }
    history.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    if (mounted) {
      setState(() {
        _tournamentHistory = history.take(5).toList();
        _historyLoading = false;
      });
    }
  }

  Future<void> _loadGadgets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gadgets')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      setState(() {
        _gadgets = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
  }

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
      body: SafeArea(
        child: Column(children: [
          // ━━━ 統一ヘッダー ━━━
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('マイページ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Spacer(),
                if (user != null)
                  StreamBuilder<int>(
                    stream: NotificationService.unreadCountStream(user.uid),
                    builder: (context, notifSnap) {
                      final unread = notifSnap.data ?? 0;
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                        child: Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: AppTheme.error,
                          child: const Icon(Icons.notifications_outlined, size: 24, color: AppTheme.textPrimary),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  child: const Icon(Icons.settings_outlined, size: 24, color: AppTheme.textPrimary),
                ),
              ]),
              const SizedBox(height: 8),
              Container(height: 1, color: Colors.grey[100]),
            ]),
          ),
          Expanded(child: user == null
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
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // アバター表示（キャッシュ対応）
                              avatarUrl.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 36,
                                      backgroundImage:
                                          CachedNetworkImageProvider(avatarUrl),
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

                    // ── 過去の大会 ──
                    _buildSectionLabel('過去の大会'),
                    const SizedBox(height: 8),
                    if (_historyLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2)),
                      )
                    else if (_tournamentHistory.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          const Text('まだ大会の参加履歴がありません',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                        ]),
                      )
                    else
                      ...(_tournamentHistory.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildTournamentHistoryCard(context, t),
                          ))),
                    const SizedBox(height: 16),

                    // ── 使用アイテム ──
                    _buildSectionLabel('使用アイテム'),
                    const SizedBox(height: 8),
                    if (_gadgets.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          const Text('使っているアイテムを登録しましょう',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showAddGadgetDialog(context, user!.uid),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('アイテムを追加'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                  color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ]),
                      )
                    else
                      Column(children: [
                        ..._gadgets.map((g) =>
                            _buildGadgetCard(context, g, user!.uid)),
                        const SizedBox(height: 8),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showAddGadgetDialog(context, user!.uid),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('アイテムを追加'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                  color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ]),
                    const SizedBox(height: 16),

                    // ── 友達をさがす ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
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
                    _buildSectionLabel('管理'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
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
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.location_city, '会場を登録・検索', () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const VenueSearchScreen()));
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 履歴・記録 ──
                    _buildSectionLabel('履歴・記録'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(Icons.people_outline,
                              '対戦ヒストリー', () => _showComingSoon(context)),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.article_outlined,
                              '自分の投稿', () => _showComingSoon(context)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── その他 ──
                    _buildSectionLabel('その他'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                              Icons.bookmark_outline,
                              'ブックマーク', () => _showComingSoon(context)),
                          _buildMenuDivider(),
                          _buildMenuItem(
                              Icons.workspace_premium_outlined,
                              'バッジコレクション', () => _showComingSoon(context)),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.leaderboard_outlined,
                              'ランキング', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RankingScreen()),
                            );
                          }),
                          _buildMenuDivider(),
                          _buildMenuItem(Icons.save_outlined,
                              'テンプレート管理', () => _showComingSoon(context)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── 過去の大会カード ──
  Widget _buildTournamentHistoryCard(
      BuildContext context, Map<String, dynamic> t) {
    final dateStr = t['date'] ?? '';
    String dateDisplay = dateStr;
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) {
        dateDisplay = '${int.parse(parts[1])}/${parts[2]}';
      }
    } catch (_) {}
    final isOrganizer = t['isOrganizer'] == true;

    return GestureDetector(
      onTap: () {
        final status = t['status'] ?? '終了';
        Color statusColor = AppTheme.textSecondary;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentDetailScreen(
              tournament: {
                'id': t['id'],
                'name': t['title'] ?? '',
                'date': t['date'] ?? '',
                'venue': t['location'] ?? '',
                'courts': t['courts'] ?? 0,
                'type': t['type'] ?? '',
                'format': t['format'] ?? '',
                'currentTeams': t['currentTeams'] ?? 0,
                'maxTeams': t['maxTeams'] ?? 8,
                'fee': t['entryFee'] ?? '',
                'status': status,
                'statusColor': statusColor,
                'deadline': '',
                'organizer': t['organizerName'] ?? '',
                'isFollowing': true,
                'organizerId': t['organizerId'] ?? '',
                'rules': t['rules'] ?? {},
                'venueAddress': t['venueAddress'] ?? '',
                'location': t['location'] ?? '',
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dateDisplay,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(t['location'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isOrganizer
                          ? AppTheme.accentColor.withValues(alpha: 0.1)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isOrganizer ? '主催' : '出場',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOrganizer
                                ? AppTheme.accentColor
                                : AppTheme.primaryColor)),
                  ),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  // ── ガジェットカード ──
  Widget _buildGadgetCard(
      BuildContext context, Map<String, dynamic> gadget, String uid) {
    final name = gadget['name'] ?? '';
    final category = gadget['category'] ?? '';
    final imageUrl = gadget['imageUrl'] ?? '';
    final amazonUrl = gadget['amazonUrl'] ?? '';
    final rakutenUrl = gadget['rakutenUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // 商品画像
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag_outlined,
                          size: 24,
                          color: Colors.grey[400])),
                )
              : Icon(Icons.shopping_bag_outlined,
                  size: 24, color: Colors.grey[400]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (category.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(category,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                if (amazonUrl.isNotEmpty)
                  _buildShopButton('Amazon', AppTheme.accentColor, amazonUrl),
                if (amazonUrl.isNotEmpty && rakutenUrl.isNotEmpty)
                  const SizedBox(width: 6),
                if (rakutenUrl.isNotEmpty)
                  _buildShopButton('楽天', AppTheme.error, rakutenUrl),
              ]),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showDeleteGadgetDialog(context, uid, gadget['id']),
          child: Icon(Icons.more_vert, size: 20, color: Colors.grey[400]),
        ),
      ]),
    );
  }

  Widget _buildShopButton(String label, Color color, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  void _showDeleteGadgetDialog(
      BuildContext context, String uid, String gadgetId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('アイテムを削除',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('このアイテムを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('gadgets')
                  .doc(gadgetId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
              _loadGadgets();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(80, 36),
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ── Amazon URL解析 ──
  Map<String, String> _parseAmazonUrl(String url) {
    final result = <String, String>{};

    // ASIN抽出
    final asinMatch =
        RegExp(r'/(?:dp|gp/product)/([A-Z0-9]{10})').firstMatch(url);
    final asin = asinMatch?.group(1) ?? '';

    if (asin.isNotEmpty) {
      result['asin'] = asin;
      result['amazonUrl'] = 'https://www.amazon.co.jp/dp/$asin';
    }

    // URL slugから商品名抽出
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final dpIndex = segments.indexOf('dp');
      if (dpIndex > 0) {
        final slug = Uri.decodeComponent(segments[dpIndex - 1]);
        result['name'] = slug.replaceAll('-', ' ');
      }
    } catch (_) {}

    return result;
  }

  // ── Amazon商品ページからOG情報取得 ──
  Future<Map<String, String>> _fetchProductInfo(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept-Language': 'ja-JP,ja;q=0.9',
      });
      if (response.statusCode != 200) return {};

      final html = response.body;
      final result = <String, String>{};

      final titleMatch = RegExp(
                  r'<meta[^>]*property="og:title"[^>]*content="([^"]*)"',
                  caseSensitive: false)
              .firstMatch(html) ??
          RegExp(r'<meta[^>]*content="([^"]*)"[^>]*property="og:title"',
                  caseSensitive: false)
              .firstMatch(html);
      if (titleMatch != null) result['name'] = titleMatch.group(1) ?? '';

      final imageMatch = RegExp(
                  r'<meta[^>]*property="og:image"[^>]*content="([^"]*)"',
                  caseSensitive: false)
              .firstMatch(html) ??
          RegExp(r'<meta[^>]*content="([^"]*)"[^>]*property="og:image"',
                  caseSensitive: false)
              .firstMatch(html);
      if (imageMatch != null) result['imageUrl'] = imageMatch.group(1) ?? '';

      return result;
    } catch (_) {
      return {};
    }
  }

  void _showAddGadgetDialog(BuildContext context, String uid) {
    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final amazonCtrl = TextEditingController();
    final rakutenCtrl = TextEditingController();
    final urlPasteCtrl = TextEditingController();
    bool isLoading = false;
    String selectedCategory = '';
    final categories = ['ボール', 'シューズ', 'ウェア', 'サポーター', 'バッグ', 'その他'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text('アイテムを追加',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),

                        // ── Amazon自動入力セクション ──
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.accentColor
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.auto_awesome,
                                    size: 18,
                                    color: AppTheme.accentColor),
                                const SizedBox(width: 6),
                                const Text('Amazon URLから自動入力',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            AppTheme.accentColor)),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  'Amazon商品ページのURLを貼り付けると商品名・画像が自動入力されます',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppTheme.textSecondary)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: urlPasteCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Amazon URLを貼り付け',
                                      hintStyle: const TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppTheme.textHint),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.grey[200]!),
                                      ),
                                      enabledBorder:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.grey[200]!),
                                      ),
                                      focusedBorder:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                        borderSide:
                                            const BorderSide(
                                                color: AppTheme
                                                    .accentColor,
                                                width: 2),
                                      ),
                                    ),
                                    style: const TextStyle(
                                        fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          final url = urlPasteCtrl
                                              .text
                                              .trim();
                                          if (url.isEmpty) return;

                                          setSheetState(() =>
                                              isLoading = true);

                                          // URL解析
                                          final parsed =
                                              _parseAmazonUrl(url);
                                          if (parsed['name']
                                                  ?.isNotEmpty ==
                                              true) {
                                            nameCtrl.text =
                                                parsed['name']!;
                                          }
                                          amazonCtrl.text =
                                              parsed['amazonUrl'] ??
                                                  url;

                                          // OG情報取得
                                          try {
                                            final info =
                                                await _fetchProductInfo(
                                                    parsed['amazonUrl'] ??
                                                        url);
                                            if (info['name']
                                                    ?.isNotEmpty ==
                                                true) {
                                              nameCtrl.text =
                                                  info['name']!;
                                            }
                                            if (info['imageUrl']
                                                    ?.isNotEmpty ==
                                                true) {
                                              imageCtrl.text =
                                                  info['imageUrl']!;
                                            }
                                          } catch (_) {}

                                          setSheetState(() =>
                                              isLoading = false);

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                                    context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    '商品情報を取得しました'),
                                                backgroundColor:
                                                    AppTheme
                                                        .success,
                                                duration: Duration(
                                                    seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.accentColor,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 42),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8)),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color:
                                                      Colors.white))
                                      : const Text('自動入力',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.bold)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final query =
                                        nameCtrl.text.isNotEmpty
                                            ? nameCtrl.text
                                            : 'バレーボール';
                                    final searchUrl = Uri.parse(
                                        'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(query)}&i=sporting');
                                    if (await canLaunchUrl(
                                        searchUrl)) {
                                      await launchUrl(searchUrl,
                                          mode: LaunchMode
                                              .externalApplication);
                                    }
                                  },
                                  icon: Icon(Icons.open_in_new,
                                      size: 14,
                                      color: AppTheme.accentColor),
                                  label: Text('Amazonで検索して探す',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme
                                              .accentColor)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── 商品名 ──
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '商品名 *',
                            hintText: 'ミカサ バレーボール V300W',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── カテゴリ（ドロップダウン） ──
                        DropdownButtonFormField<String>(
                          value: selectedCategory.isEmpty
                              ? null
                              : selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'カテゴリ',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setSheetState(
                              () => selectedCategory = v ?? ''),
                          hint: const Text('カテゴリを選択'),
                        ),
                        const SizedBox(height: 12),

                        // ── 画像URL + プレビュー ──
                        TextField(
                          controller: imageCtrl,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: '画像URL',
                            hintText: 'https://...',
                            border: const OutlineInputBorder(),
                            suffixIcon: imageCtrl.text
                                    .trim()
                                    .isNotEmpty
                                ? Padding(
                                    padding:
                                        const EdgeInsets.all(4),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: Image.network(
                                        imageCtrl.text.trim(),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                const Icon(
                                                    Icons
                                                        .broken_image,
                                                    size: 20),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Amazon URL ──
                        TextField(
                          controller: amazonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Amazon URL',
                            hintText: 'https://amazon.co.jp/dp/...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── 楽天 URL ──
                        TextField(
                          controller: rakutenCtrl,
                          decoration: const InputDecoration(
                            labelText: '楽天 URL',
                            hintText: 'https://a.r10.to/...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── 追加ボタン ──
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('商品名を入力してください')),
                                );
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('gadgets')
                                  .add({
                                'name': nameCtrl.text.trim(),
                                'category': selectedCategory,
                                'imageUrl': imageCtrl.text.trim(),
                                'amazonUrl': amazonCtrl.text.trim(),
                                'rakutenUrl':
                                    rakutenCtrl.text.trim(),
                                'createdAt':
                                    FieldValue.serverTimestamp(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadGadgets();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: const Text('追加',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
