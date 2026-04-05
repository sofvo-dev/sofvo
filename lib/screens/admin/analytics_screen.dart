import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// アクセス解析画面（公式アカウント専用）
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _firestore = FirebaseFirestore.instance;
  Future<_AnalyticsData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_AnalyticsData> _loadData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final fourteenDaysAgo = today.subtract(const Duration(days: 13));

    // ── ユーザー関連 ──
    final usersRef = _firestore.collection('users');

    // 累計ユーザー
    final totalSnap = await usersRef.count().get();
    final totalUsers = totalSnap.count ?? 0;

    // 過去14日分のユーザーを取得して日別にグループ化
    final recentUsersSnap = await usersRef
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fourteenDaysAgo))
        .get();

    // 日別カウント
    final dailyCounts = <DateTime, int>{};
    for (var i = 0; i < 14; i++) {
      dailyCounts[fourteenDaysAgo.add(Duration(days: i))] = 0;
    }

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;

    for (final doc in recentUsersSnap.docs) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      if (createdAt == null || createdAt is! Timestamp) continue;
      final date = createdAt.toDate();
      final dayKey = DateTime(date.year, date.month, date.day);

      if (dailyCounts.containsKey(dayKey)) {
        dailyCounts[dayKey] = dailyCounts[dayKey]! + 1;
      }

      if (!dayKey.isBefore(today)) todayCount++;
      if (!dayKey.isBefore(weekAgo)) weekCount++;
      if (!dayKey.isBefore(monthStart)) monthCount++;
    }

    // monthStart が14日より前の場合、追加でクエリ
    if (monthStart.isBefore(fourteenDaysAgo)) {
      final earlyMonthSnap = await usersRef
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('createdAt', isLessThan: Timestamp.fromDate(fourteenDaysAgo))
          .get();
      monthCount += earlyMonthSnap.size;
    }

    // ── コンテンツ統計 ──
    final monthTimestamp = Timestamp.fromDate(monthStart);

    final postsSnap = await _firestore
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: monthTimestamp)
        .count()
        .get();

    final tournamentsSnap = await _firestore
        .collection('tournaments')
        .where('createdAt', isGreaterThanOrEqualTo: monthTimestamp)
        .count()
        .get();

    final chatsSnap = await _firestore
        .collection('chats')
        .where('createdAt', isGreaterThanOrEqualTo: monthTimestamp)
        .count()
        .get();

    // 日別データをソート済みリストに変換
    final sortedDays = dailyCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _AnalyticsData(
      todayNew: todayCount,
      weekNew: weekCount,
      monthNew: monthCount,
      totalUsers: totalUsers,
      dailyRegistrations: sortedDays,
      monthPosts: postsSnap.count ?? 0,
      monthTournaments: tournamentsSnap.count ?? 0,
      monthChats: chatsSnap.count ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('アクセス解析',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _loadData();
          setState(() => _future = future);
          await future;
        },
        child: FutureBuilder<_AnalyticsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('データの取得に失敗しました',
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _future = _loadData()),
                      child: const Text('再読み込み'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('サマリー', Icons.dashboard_rounded),
                const SizedBox(height: 12),
                _buildSummaryCards(data),
                const SizedBox(height: 24),
                _buildSectionTitle('日別新規登録数', Icons.bar_chart_rounded),
                const SizedBox(height: 4),
                Text('過去14日間',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 12),
                _buildBarChart(data.dailyRegistrations),
                const SizedBox(height: 24),
                _buildSectionTitle('コンテンツ統計', Icons.content_paste_rounded),
                const SizedBox(height: 4),
                Text('今月',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 12),
                _buildContentStats(data),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildSummaryCards(_AnalyticsData data) {
    final items = [
      _SummaryItem('今日の新規', data.todayNew, Icons.today_rounded, Colors.green),
      _SummaryItem('今週の新規', data.weekNew, Icons.date_range_rounded, Colors.blue),
      _SummaryItem(
          '今月の新規', data.monthNew, Icons.calendar_month_rounded, Colors.orange),
      _SummaryItem(
          '累計ユーザー', data.totalUsers, Icons.people_rounded, AppTheme.primaryColor),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: items.map((item) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 18, color: item.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item.label,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(List<MapEntry<DateTime, int>> dailyData) {
    final maxCount = dailyData.fold<int>(
        0, (prev, e) => e.value > prev ? e.value : prev);
    final effectiveMax = maxCount == 0 ? 1 : maxCount;
    const maxHeight = 120.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        children: [
          // 最大値ラベル
          Row(
            children: [
              Text('最大: $maxCount人',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: maxHeight + 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyData.map((entry) {
                final date = entry.key;
                final count = entry.value;
                final barHeight = maxHeight * (count / effectiveMax);
                final label = '${date.month}/${date.day}';

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('$count',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[600])),
                        ),
                      Container(
                        width: double.infinity,
                        height: count > 0 ? barHeight.clamp(4.0, maxHeight) : 2,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? AppTheme.primaryColor
                              : Colors.grey[200],
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Transform.rotate(
                        angle: -0.5,
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 8, color: Colors.grey[500])),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStats(_AnalyticsData data) {
    final items = [
      _SummaryItem(
          '今月の投稿数', data.monthPosts, Icons.article_rounded, Colors.teal),
      _SummaryItem('今月の大会数', data.monthTournaments,
          Icons.emoji_events_rounded, AppTheme.accentColor),
      _SummaryItem('今月のチャット作成数', data.monthChats,
          Icons.chat_bubble_rounded, Colors.purple),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 22, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.label,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary)),
              ),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AnalyticsData {
  final int todayNew;
  final int weekNew;
  final int monthNew;
  final int totalUsers;
  final List<MapEntry<DateTime, int>> dailyRegistrations;
  final int monthPosts;
  final int monthTournaments;
  final int monthChats;

  _AnalyticsData({
    required this.todayNew,
    required this.weekNew,
    required this.monthNew,
    required this.totalUsers,
    required this.dailyRegistrations,
    required this.monthPosts,
    required this.monthTournaments,
    required this.monthChats,
  });
}

class _SummaryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  _SummaryItem(this.label, this.count, this.icon, this.color);
}
