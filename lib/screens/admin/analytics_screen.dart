import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// アクセス解析画面（公式アカウント専用）
/// Cloud Functions の getAnalytics を使用（Admin SDK でセキュリティルール制限なし）
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<_AnalyticsData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_AnalyticsData> _loadData() async {
    final _firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final fourteenDaysAgo = today.subtract(const Duration(days: 13));

    final usersRef = _firestore.collection('users');

    // 並列で全クエリ実行
    final results = await Future.wait([
      usersRef.count().get(),                                                    // 0: total
      usersRef.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fourteenDaysAgo)).get(), // 1: recent
      _firestore.collection('posts').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart)).count().get(),  // 2: posts
      _firestore.collection('tournaments').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart)).count().get(), // 3: tournaments
      usersRef.where('isDemo', isEqualTo: true).count().get(),                   // 4: 体験デモのゲスト（登録者数から除外する）
      _firestore.collection('tournaments').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart)).where('isDemo', isEqualTo: true).count().get(), // 5: 今月の体験デモ大会
    ]);

    // 体験デモの匿名ゲスト（isDemo:true）は登録者数に含めない。
    // cleanupDemoData で削除されるまでの間カウントに乗ってしまうため差し引く。
    final demoUsers = (results[4] as AggregateQuerySnapshot).count ?? 0;
    final demoTournaments = (results[5] as AggregateQuerySnapshot).count ?? 0;
    final totalUsers = ((results[0] as AggregateQuerySnapshot).count ?? 0) - demoUsers;
    final recentUsersSnap = results[1] as QuerySnapshot;
    final monthPosts = (results[2] as AggregateQuerySnapshot).count ?? 0;
    final monthTournaments = ((results[3] as AggregateQuerySnapshot).count ?? 0) - demoTournaments;

    // 日別カウント
    final dailyEntries = <MapEntry<DateTime, int>>[];
    final dailyCounts = <String, int>{};
    for (var i = 0; i < 14; i++) {
      final d = fourteenDaysAgo.add(Duration(days: i));
      dailyCounts['${d.year}-${d.month}-${d.day}'] = 0;
    }
    int todayCount = 0, weekCount = 0, monthCount = 0;
    for (final doc in recentUsersSnap.docs) {
      final data = doc.data() is Map ? (doc.data() as Map) : null;
      if (data == null) continue;
      if (data['isDemo'] == true) continue; // 体験デモのゲストは新規登録に数えない
      final createdAt = data['createdAt'];
      if (createdAt == null || createdAt is! Timestamp) continue;
      final date = createdAt.toDate();
      final dayKey = '${date.year}-${date.month}-${date.day}';
      if (dailyCounts.containsKey(dayKey)) dailyCounts[dayKey] = dailyCounts[dayKey]! + 1;
      final dayStart = DateTime(date.year, date.month, date.day);
      if (!dayStart.isBefore(today)) todayCount++;
      if (!dayStart.isBefore(weekAgo)) weekCount++;
      if (!dayStart.isBefore(monthStart)) monthCount++;
    }
    final sortedDays = dailyCounts.entries.toList()..sort((a, b) {
      final ap = a.key.split('-').map(int.parse).toList();
      final bp = b.key.split('-').map(int.parse).toList();
      return DateTime(ap[0], ap[1], ap[2]).compareTo(DateTime(bp[0], bp[1], bp[2]));
    });
    for (final e in sortedDays) {
      final p = e.key.split('-').map(int.parse).toList();
      dailyEntries.add(MapEntry(DateTime(p[0], p[1], p[2]), e.value));
    }

    return _AnalyticsData(
      todayNew: todayCount,
      weekNew: weekCount,
      monthNew: monthCount,
      totalUsers: totalUsers,
      dailyRegistrations: dailyEntries,
      monthPosts: monthPosts,
      monthTournaments: monthTournaments,
      monthChats: 0, // chatsはセキュリティルール制限のため取得不可
      dau: 0,
      wau: 0,
      mau: 0,
      retentionRate: 0,
      monthMessages: 0,
      totalChats: 0,
      segments: {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
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
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
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
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text('${snapshot.error}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          textAlign: TextAlign.center),
                    ),
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
                const SizedBox(height: 24),
                _buildSectionTitle('アクティブユーザー', Icons.groups_rounded),
                const SizedBox(height: 12),
                _buildActiveUsersCards(data),
                const SizedBox(height: 24),
                _buildSectionTitle('リテンション', Icons.repeat_rounded),
                const SizedBox(height: 12),
                _buildRetentionCard(data),
                const SizedBox(height: 24),
                _buildSectionTitle('チャット活動', Icons.forum_rounded),
                const SizedBox(height: 12),
                _buildChatActivityCards(data),
                const SizedBox(height: 24),
                _buildSectionTitle('ユーザーセグメント', Icons.pie_chart_rounded),
                const SizedBox(height: 4),
                Text('経験レベル別',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 12),
                _buildSegmentsSection(data),
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
  Widget _buildActiveUsersCards(_AnalyticsData data) {
    final items = [
      _SummaryItem('DAU (今日)', data.dau, Icons.person_rounded, Colors.green),
      _SummaryItem(
          'WAU (7日間)', data.wau, Icons.group_rounded, Colors.blue),
      _SummaryItem(
          'MAU (30日間)', data.mau, Icons.groups_rounded, AppTheme.primaryColor),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(item.icon, size: 22, color: item.color),
                const SizedBox(height: 6),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRetentionCard(_AnalyticsData data) {
    final rate = data.retentionRate;
    final color = rate >= 50
        ? Colors.green
        : rate >= 25
            ? Colors.orange
            : Colors.red;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.repeat_rounded, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('週次リテンション率',
                    style:
                        TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                Text('前週アクティブ → 今週もアクティブ',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(
            '$rate%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatActivityCards(_AnalyticsData data) {
    final items = [
      _SummaryItem('チャット総数', data.totalChats,
          Icons.chat_bubble_outline_rounded, AppTheme.primaryColor),
      _SummaryItem('今月のメッセージ数', data.monthMessages,
          Icons.message_rounded, Colors.deepPurple),
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

  Widget _buildSegmentsSection(_AnalyticsData data) {
    if (data.segments.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Text('データなし',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      );
    }

    final total =
        data.segments.values.fold<int>(0, (sum, v) => sum + v);
    final effectiveTotal = total == 0 ? 1 : total;

    final segmentColors = <String, Color>{
      'beginner': Colors.blue,
      'intermediate': Colors.orange,
      'advanced': Colors.red,
      'expert': Colors.purple,
      'unknown': Colors.grey,
    };

    final segmentLabels = <String, String>{
      'beginner': '初心者',
      'intermediate': '中級者',
      'advanced': '上級者',
      'expert': 'エキスパート',
      'unknown': '未設定',
    };

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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: data.segments.entries.map((entry) {
          final color = segmentColors[entry.key] ?? Colors.grey;
          final label = segmentLabels[entry.key] ?? entry.key;
          final percent = (entry.value / effectiveTotal * 100).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textPrimary)),
                    Text('${entry.value}人 ($percent%)',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / effectiveTotal,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
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
  final int dau;
  final int wau;
  final int mau;
  final int retentionRate;
  final int monthMessages;
  final int totalChats;
  final Map<String, int> segments;

  _AnalyticsData({
    required this.todayNew,
    required this.weekNew,
    required this.monthNew,
    required this.totalUsers,
    required this.dailyRegistrations,
    required this.monthPosts,
    required this.monthTournaments,
    required this.monthChats,
    required this.dau,
    required this.wau,
    required this.mau,
    required this.retentionRate,
    required this.monthMessages,
    required this.totalChats,
    required this.segments,
  });
}

class _SummaryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  _SummaryItem(this.label, this.count, this.icon, this.color);
}
