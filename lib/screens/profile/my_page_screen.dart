import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/affiliate_config.dart';
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
              // ━━━ コンパクトヘッダー ━━━
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 14),
                      child: Column(
                        children: [
                          // ── トップバー ──
                          Row(
                            children: [
                              const Text('マイページ',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                              const Spacer(),
                              StreamBuilder<int>(
                                stream: NotificationService.unreadCountStream(user.uid),
                                builder: (context, notifSnap) {
                                  final unread = notifSnap.data ?? 0;
                                  return IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                                    icon: Badge(
                                      isLabelVisible: unread > 0,
                                      label: Text('$unread', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: AppTheme.error,
                                      child: const Icon(Icons.notifications_outlined, size: 20, color: Colors.white),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                                icon: const Icon(Icons.settings_outlined, size: 20, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // ── プロフィール行（横レイアウト） ──
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => ProfileEditScreen(userData: data))),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                                  ),
                                  child: avatarUrl.isNotEmpty
                                      ? CircleAvatar(
                                          radius: 30,
                                          backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                                        )
                                      : CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                                          child: Text(
                                            nickname.isNotEmpty ? nickname[0] : '?',
                                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nickname,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (experience.isNotEmpty) _buildHeaderTag('競技歴 $experience'),
                                        if (area.isNotEmpty) _buildHeaderTag(area),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => ProfileEditScreen(userData: data))),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('編集', style: TextStyle(fontSize: 12, color: Colors.white)),
                              ),
                            ],
                          ),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(bio,
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), height: 1.3),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // ── フォロー / フォロワー（横一列コンパクト） ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFollowCount(context, '$followingCount', 'フォロー', () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                      userId: user.uid, title: 'フォロー中', isFollowers: false)));
                              }),
                              Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 24),
                                  color: Colors.white.withValues(alpha: 0.25)),
                              _buildFollowCount(context, '$followersCount', 'フォロワー', () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => FollowListScreen(
                                      userId: user.uid, title: 'フォロワー', isFollowers: true)));
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ━━━ ダッシュボード（スタッツ） ━━━
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildDashboardStat(Icons.star_rounded, '$totalPoints', '通算Pt', AppTheme.accentColor)),
                        Container(width: 1, height: 60, color: Colors.grey[200]),
                        Expanded(child: _buildDashboardStat(Icons.emoji_events_rounded, '$tournamentsPlayed', '大会参加', AppTheme.primaryColor)),
                        Container(width: 1, height: 60, color: Colors.grey[200]),
                        Expanded(child: _buildDashboardStat(Icons.military_tech_rounded, '$championships', '優勝', AppTheme.warning)),
                      ],
                    ),
                  ),
                ),
              ),

              // ━━━ コンテンツ ━━━
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ━━━ 大会結果カードセクション ━━━
                    _buildCardSection(
                      context: context,
                      title: '大会結果',
                      icon: Icons.emoji_events_rounded,
                      child: _TournamentCardsRow(userId: user.uid),
                    ),
                    const SizedBox(height: 16),

                    // ━━━ マイガジェットカードセクション ━━━
                    _buildCardSection(
                      context: context,
                      title: 'マイガジェット',
                      icon: Icons.devices_other_rounded,
                      seeAllTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const GadgetListScreen())),
                      child: _GadgetCardsRow(userId: user.uid),
                    ),
                    const SizedBox(height: 16),

                    // ━━━ バッジコレクション（YAMAP風） ━━━
                    _buildCardSection(
                      context: context,
                      title: 'バッジコレクション',
                      icon: Icons.workspace_premium_rounded,
                      child: _BadgeCollectionRow(userId: user.uid),
                    ),
                    const SizedBox(height: 16),

                    // ── 友達をさがす ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildActionCard(
                        icon: Icons.person_add_rounded,
                        title: '友達をさがす',
                        subtitle: 'QRコード・ID検索・ユーザー検索',
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const FollowSearchScreen())),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 管理 ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionLabel('管理'),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMenuGroup([
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
                    ),
                    const SizedBox(height: 20),

                    // ── 履歴・記録 ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionLabel('履歴・記録'),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMenuGroup([
                        _MenuItemData(Icons.history_rounded, '参加大会履歴', () => _showComingSoon(context)),
                        _MenuItemData(Icons.people_outline_rounded, '対戦ヒストリー', () => _showComingSoon(context)),
                        _MenuItemData(Icons.article_outlined, '自分の投稿', () => _showComingSoon(context)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── その他 ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionLabel('その他'),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMenuGroup([
                        _MenuItemData(Icons.bookmark_outline_rounded, 'ブックマーク', () => _showComingSoon(context)),
                        _MenuItemData(Icons.workspace_premium_outlined, 'バッジコレクション', () => _showComingSoon(context)),
                        _MenuItemData(Icons.leaderboard_outlined, 'ランキング', () => _showComingSoon(context)),
                        _MenuItemData(Icons.save_outlined, 'テンプレート管理', () => _showComingSoon(context)),
                      ]),
                    ),
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
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color, height: 1.1)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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

  // ── カードセクション（タイトル + 横スクロール） ──
  Widget _buildCardSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? seeAllTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const Spacer(),
              if (seeAllTap != null)
                GestureDetector(
                  onTap: seeAllTap,
                  child: Row(
                    children: [
                      Text('すべて見る', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryColor),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
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
// 大会結果カード（横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TournamentCardsRow extends StatelessWidget {
  final String userId;
  const _TournamentCardsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .where('status', isEqualTo: '終了')
          .orderBy('date', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final allTournaments = snapshot.data?.docs ?? [];
        // ユーザーが主催 or 参加した大会をフィルタ（クライアント側）
        // organizerId でまずフィルタ、entries はサブコレクションなので主催大会のみ表示
        final tournaments = allTournaments.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['organizerId'] == userId;
        }).take(10).toList();

        if (tournaments.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text('まだ大会結果がありません', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          );
        }

        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = tournaments[index];
              final d = doc.data() as Map<String, dynamic>;
              final title = (d['title'] ?? d['name'] ?? '大会') as String;
              final date = (d['date'] ?? '') as String;
              final location = (d['location'] ?? d['venue'] ?? '') as String;
              final status = (d['status'] ?? '') as String;
              final type = (d['type'] ?? '') as String;

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {...d, 'id': doc.id}))),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == '終了'
                                  ? AppTheme.textSecondary.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status.isEmpty ? '終了' : status,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: status == '終了' ? AppTheme.textSecondary : AppTheme.primaryColor)),
                          ),
                          if (type.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentColor)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place, size: 11, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(location, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ガジェットカード（横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _GadgetCardsRow extends StatelessWidget {
  final String userId;
  const _GadgetCardsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(userId).collection('gadgets')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final gadgets = snapshot.data?.docs ?? [];

        if (gadgets.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ガジェットを登録しよう', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GadgetListScreen())),
                    child: Text('登録する', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gadgets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final d = gadgets[index].data() as Map<String, dynamic>;
              final name = (d['name'] ?? '') as String;
              final category = (d['category'] ?? '') as String;
              final imageUrl = (d['imageUrl'] ?? '') as String;
              final amazonUrl = (d['amazonUrl'] ?? '').toString();
              final rakutenUrl = (d['rakutenUrl'] ?? '').toString();

              return Container(
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 画像エリア ──
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const GadgetListScreen())),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: SizedBox(
                          height: 72,
                          width: double.infinity,
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 24)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: Icon(Icons.devices_other, color: Colors.grey, size: 24)),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                  child: const Center(child: Icon(Icons.devices_other, color: AppTheme.primaryColor, size: 28)),
                                ),
                        ),
                      ),
                    ),
                    // ── テキスト ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (category.isNotEmpty && category != 'カテゴリなし') ...[
                            const SizedBox(height: 1),
                            Text(category, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // ── Amazon / 楽天 ミニボタン ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
                      child: Row(
                        children: [
                          if (amazonUrl.isNotEmpty)
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final url = AffiliateConfig.buildAmazonAffiliateUrl(amazonUrl);
                                  final uri = Uri.tryParse(url);
                                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9900).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Text('Amazon', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF9900))),
                                  ),
                                ),
                              ),
                            ),
                          if (amazonUrl.isNotEmpty && rakutenUrl.isNotEmpty)
                            const SizedBox(width: 3),
                          if (rakutenUrl.isNotEmpty)
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final url = AffiliateConfig.buildRakutenAffiliateUrl(rakutenUrl);
                                  final uri = Uri.tryParse(url);
                                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBF0000).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Text('楽天', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFBF0000))),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// バッジコレクション（YAMAP風 横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BadgeCollectionRow extends StatelessWidget {
  final String userId;
  const _BadgeCollectionRow({required this.userId});

  // バッジ定義（YAMAP風の達成系バッジ）
  static const _badgeDefinitions = [
    _BadgeDef('初参加', Icons.flag_rounded, Color(0xFF4CAF50), 'tournamentsPlayed', 1),
    _BadgeDef('5大会参加', Icons.emoji_events_rounded, Color(0xFF2196F3), 'tournamentsPlayed', 5),
    _BadgeDef('10大会参加', Icons.emoji_events_rounded, Color(0xFF9C27B0), 'tournamentsPlayed', 10),
    _BadgeDef('初優勝', Icons.military_tech_rounded, Color(0xFFFF9800), 'championships', 1),
    _BadgeDef('3回優勝', Icons.military_tech_rounded, Color(0xFFF44336), 'championships', 3),
    _BadgeDef('100Pt達成', Icons.star_rounded, Color(0xFFFFC107), 'totalPoints', 100),
    _BadgeDef('500Pt達成', Icons.star_rounded, Color(0xFFFF5722), 'totalPoints', 500),
    _BadgeDef('1000Pt達成', Icons.diamond_rounded, Color(0xFFE91E63), 'totalPoints', 1000),
    _BadgeDef('ガジェット5個', Icons.devices_other_rounded, Color(0xFF00BCD4), 'gadgetCount', 5),
    _BadgeDef('フォロワー10', Icons.people_rounded, Color(0xFF795548), 'followersCount', 10),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final stats = data['stats'] is Map<String, dynamic>
            ? data['stats'] as Map<String, dynamic>
            : <String, dynamic>{};

        // 各値を取得
        final values = {
          'tournamentsPlayed': _intVal(stats['tournamentsPlayed']),
          'championships': _intVal(stats['championships']),
          'totalPoints': _intVal(data['totalPoints']),
          'gadgetCount': _intVal(data['gadgetCount']),
          'followersCount': _intVal(data['followersCount']),
        };

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _badgeDefinitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = _badgeDefinitions[index];
              final currentValue = values[badge.statKey] ?? 0;
              final earned = currentValue >= badge.threshold;

              return Container(
                width: 90,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: earned ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: earned ? badge.color.withValues(alpha: 0.4) : Colors.grey[200]!,
                    width: earned ? 1.5 : 1,
                  ),
                  boxShadow: earned
                      ? [BoxShadow(color: badge.color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned
                            ? badge.color.withValues(alpha: 0.12)
                            : Colors.grey[200],
                        border: earned
                            ? Border.all(color: badge.color.withValues(alpha: 0.3), width: 2)
                            : null,
                      ),
                      child: Icon(
                        badge.icon,
                        color: earned ? badge.color : Colors.grey[400],
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: earned ? FontWeight.bold : FontWeight.normal,
                        color: earned ? AppTheme.textPrimary : AppTheme.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (!earned)
                      Text(
                        '$currentValue/${badge.threshold}',
                        style: TextStyle(fontSize: 9, color: AppTheme.textHint),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  int _intVal(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }
}

class _BadgeDef {
  final String name;
  final IconData icon;
  final Color color;
  final String statKey;
  final int threshold;
  const _BadgeDef(this.name, this.icon, this.color, this.statKey, this.threshold);
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
