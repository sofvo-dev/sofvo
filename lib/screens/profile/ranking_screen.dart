import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../services/point_service.dart';
import 'user_profile_screen.dart';

/// ランキング画面
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('ランキング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () => _showPointSystemInfo(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '通算Pt'),
            Tab(text: 'シーズンPt'),
            Tab(text: '大会参加'),
            Tab(text: '優勝'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAlivePage(child: const _RankingList(sortField: 'totalPoints', label: 'Pt')),
          _KeepAlivePage(child: const _RankingList(sortField: 'seasonPoints', label: 'Pt', isSeason: true)),
          _KeepAlivePage(child: const _RankingList(sortField: 'stats.tournamentsPlayed', label: '回')),
          _KeepAlivePage(child: const _RankingList(sortField: 'stats.championships', label: '回')),
        ],
      ),
    );
  }

  void _showPointSystemInfo(BuildContext context) {
    final exampleTable = PointService.getPointTable(16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('ポイントの仕組み',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 20),

              // 順位ポイント
              _buildInfoSection(
                icon: Icons.emoji_events,
                color: Colors.amber,
                title: '順位ポイント',
                description: '参加チーム数 × 順位係数\nチーム数が多い大会ほど高ポイント！',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(children: [
                        const SizedBox(width: 60, child: Text('順位', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        const SizedBox(width: 50, child: Text('係数', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        const Expanded(child: Text('16チーム例', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                      ]),
                      const Divider(),
                      _buildPointRow('優勝', '×3.0', '${exampleTable['優勝']}pt'),
                      _buildPointRow('準優勝', '×2.0', '${exampleTable['準優勝']}pt'),
                      _buildPointRow('3位', '×1.5', '${exampleTable['3位']}pt'),
                      _buildPointRow('4位', '×1.2', '${exampleTable['4位']}pt'),
                      _buildPointRow('参加', '×1.0', '${exampleTable['参加']}pt'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // MVPボーナス
              _buildInfoSection(
                icon: Icons.star,
                color: AppTheme.accentColor,
                title: 'MVPボーナス',
                description: '大会MVP投票で最多得票者に追加ポイント\n参加チーム数 × 0.5',
              ),
              const SizedBox(height: 16),

              // ストリークボーナス
              _buildInfoSection(
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
                title: '連続参加ボーナス',
                description: '連続して大会に参加するとボーナス！',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _buildPointRow('2大会連続', '', '+5pt'),
                    _buildPointRow('3大会連続', '', '+10pt'),
                    _buildPointRow('4大会以上', '', '+15pt'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // 主催者ボーナス
              _buildInfoSection(
                icon: Icons.volunteer_activism,
                color: AppTheme.success,
                title: '主催者ボーナス',
                description: '大会を開催するだけでポイント獲得！\n参加チーム数 × 0.3',
              ),
              const SizedBox(height: 16),

              // シーズン
              _buildInfoSection(
                icon: Icons.calendar_today,
                color: AppTheme.info,
                title: 'シーズン制',
                description: '毎年4月にシーズンポイントがリセット\n通算ポイントは永久に蓄積されます',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ]),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textSecondary)),
          if (child != null) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildPointRow(String label, String multiplier, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13))),
        SizedBox(width: 50, child: Text(multiplier, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Expanded(child: Text(points, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String sortField;
  final String label;
  final bool isSeason;

  const _RankingList({required this.sortField, required this.label, this.isSeason = false});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(sortField, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('ランキングデータがありません'));
        }

        return Column(
          children: [
            if (isSeason)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    '${DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1}年度シーズン',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                  ),
                ]),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final nickname = _str(data['nickname']);
                  final avatarUrl = _str(data['avatarUrl']);
                  final isMe = userId == uid;

                  int value;
                  if (sortField.contains('.')) {
                    final parts = sortField.split('.');
                    final stats = data[parts[0]] is Map<String, dynamic>
                        ? data[parts[0]] as Map<String, dynamic>
                        : {};
                    value = _intVal(stats[parts[1]]);
                  } else {
                    value = _intVal(data[sortField]);
                  }

                  final rank = index + 1;

                  return GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppTheme.primaryColor.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isMe
                            ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: rank <= 3
                                ? Icon(Icons.emoji_events,
                                    color: _rankColor(rank), size: 28)
                                : Text('$rank',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary),
                                    textAlign: TextAlign.center),
                          ),
                          const SizedBox(width: 12),
                          avatarUrl.isNotEmpty
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                )
                              : CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  child: Text(
                                    nickname.isNotEmpty ? nickname[0] : '?',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nickname.isEmpty ? '名無し' : nickname,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                      color: isMe ? AppTheme.primaryColor : AppTheme.textPrimary,
                                    )),
                                if (isMe)
                                  Text('あなた',
                                      style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                          Text('$value',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: rank <= 3 ? _rankColor(rank) : AppTheme.textPrimary,
                              )),
                          const SizedBox(width: 4),
                          Text(label,
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFFFD700);
      case 2: return const Color(0xFFC0C0C0);
      case 3: return const Color(0xFFCD7F32);
      default: return AppTheme.textSecondary;
    }
  }

  String _str(dynamic v) => v is String ? v : '';
  int _intVal(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
