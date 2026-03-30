import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../widgets/official_badge.dart';
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
            onPressed: () => PointService.showPointSystemInfo(context),
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

        final users = (snapshot.data?.docs ?? [])
            .where((d) => (d.data() as Map<String, dynamic>)['isOfficial'] != true)
            .toList();
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
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
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
                                Row(
                                  children: [
                                    Flexible(child: Text(nickname.isEmpty ? '名無し' : nickname,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                          color: isMe ? AppTheme.primaryColor : AppTheme.textPrimary,
                                        ), overflow: TextOverflow.ellipsis)),
                                    if (data['isOfficial'] == true)
                                      const OfficialBadge(size: 15),
                                  ],
                                ),
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
