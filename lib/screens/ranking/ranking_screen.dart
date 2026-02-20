import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../profile/user_profile_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'ポイント'),
            Tab(text: '参加数'),
            Tab(text: '優勝数'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRankingList('totalPoints', 'pt'),
          _buildRankingList('stats.tournamentsPlayed', '回'),
          _buildRankingList('stats.championships', '回'),
        ],
      ),
    );
  }

  Widget _buildRankingList(String field, String unit) {
    // Firestoreのドット記法はクエリに使えないため、全ユーザーを取得してソート
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('データがありません'));
        }

        final users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          int value = 0;
          if (field.contains('.')) {
            final parts = field.split('.');
            final nested = data[parts[0]];
            if (nested is Map<String, dynamic>) {
              value = (nested[parts[1]] is int)
                  ? nested[parts[1]] as int
                  : (nested[parts[1]] is double)
                      ? (nested[parts[1]] as double).toInt()
                      : 0;
            }
          } else {
            value = (data[field] is int)
                ? data[field] as int
                : (data[field] is double)
                    ? (data[field] as double).toInt()
                    : 0;
          }
          return {
            'uid': doc.id,
            'nickname': data['nickname'] ?? '名前なし',
            'avatarUrl': data['avatarUrl'] ?? '',
            'area': data['area'] ?? '',
            'experience': data['experience'] ?? '',
            'value': value,
          };
        }).toList();

        users.sort(
            (a, b) => (b['value'] as int).compareTo(a['value'] as int));
        final ranked = users.take(100).toList();
        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: ranked.length,
          itemBuilder: (context, index) {
            final user = ranked[index];
            final isMe = user['uid'] == myUid;
            final rank = index + 1;

            return Container(
              color: isMe
                  ? AppTheme.primaryColor.withValues(alpha: 0.06)
                  : Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                leading: SizedBox(
                  width: 56,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: rank <= 3
                            ? Icon(
                                Icons.emoji_events,
                                color: rank == 1
                                    ? const Color(0xFFFFD700)
                                    : rank == 2
                                        ? const Color(0xFFC0C0C0)
                                        : const Color(0xFFCD7F32),
                                size: 22,
                              )
                            : Text(
                                '$rank',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 4),
                      (user['avatarUrl'] as String).isNotEmpty
                          ? CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(
                                  user['avatarUrl'] as String),
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                            )
                          : CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                              child: Text(
                                (user['nickname'] as String)
                                        .isNotEmpty
                                    ? (user['nickname'] as String)[0]
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor),
                              ),
                            ),
                    ],
                  ),
                ),
                title: Text(
                  '${user['nickname']}${isMe ? ' (自分)' : ''}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Row(
                  children: [
                    if ((user['area'] as String).isNotEmpty) ...[
                      Icon(Icons.location_on,
                          size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 2),
                      Text(user['area'] as String,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                    ],
                    if ((user['experience'] as String).isNotEmpty) ...[
                      Icon(Icons.sports_volleyball,
                          size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 2),
                      Text(user['experience'] as String,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? AppTheme.accentColor.withValues(alpha: 0.12)
                        : AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${user['value']}$unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3
                          ? AppTheme.accentColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
                onTap: () {
                  if (!isMe) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                            userId: user['uid'] as String),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
