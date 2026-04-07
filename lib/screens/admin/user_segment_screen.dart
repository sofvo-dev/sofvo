import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// ユーザーセグメント画面（管理者用）
class UserSegmentScreen extends StatefulWidget {
  const UserSegmentScreen({super.key});

  @override
  State<UserSegmentScreen> createState() => _UserSegmentScreenState();
}

class _UserSegmentScreenState extends State<UserSegmentScreen> {
  Future<_SegmentData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_SegmentData> _loadData() async {
    final db = FirebaseFirestore.instance;
    final usersSnap = await db.collection('users').get();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    int totalUsers = 0, activeUsers = 0, inactiveUsers = 0, newUsers = 0;
    final experienceSegments = <String, int>{};
    final areaSegments = <String, int>{};
    final genderSegments = <String, int>{};

    for (final doc in usersSnap.docs) {
      final d = doc.data();
      totalUsers++;

      final lastActiveAt = d['lastActiveAt'];
      if (lastActiveAt is Timestamp && lastActiveAt.toDate().isAfter(thirtyDaysAgo)) {
        activeUsers++;
      } else {
        inactiveUsers++;
      }

      final createdAt = d['createdAt'];
      if (createdAt is Timestamp && createdAt.toDate().isAfter(sevenDaysAgo)) {
        newUsers++;
      }

      final exp = (d['experience'] as String?) ?? '未設定';
      experienceSegments[exp] = (experienceSegments[exp] ?? 0) + 1;

      final area = (d['area'] as String?) ?? '未設定';
      areaSegments[area] = (areaSegments[area] ?? 0) + 1;

      final gender = (d['gender'] as String?) ?? '未設定';
      genderSegments[gender] = (genderSegments[gender] ?? 0) + 1;
    }

    return _SegmentData(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      inactiveUsers: inactiveUsers,
      newUsers: newUsers,
      experienceSegments: experienceSegments,
      areaSegments: areaSegments,
      genderSegments: genderSegments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('ユーザーセグメント',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _loadData();
          setState(() => _future = future);
          await future;
        },
        child: FutureBuilder<_SegmentData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor));
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
                // サマリーカード
                _buildSectionTitle('サマリー', Icons.dashboard_rounded),
                const SizedBox(height: 12),
                _buildSummaryCards(data),
                const SizedBox(height: 24),

                // 競技歴別
                _buildSectionTitle('競技歴別', Icons.sports_rounded),
                const SizedBox(height: 12),
                _buildSegmentBars(
                  data.experienceSegments,
                  data.totalUsers,
                  _experienceColors,
                ),
                const SizedBox(height: 24),

                // エリア別（上位10）
                _buildSectionTitle('エリア別（上位10）', Icons.location_on_rounded),
                const SizedBox(height: 12),
                _buildSegmentBars(
                  _topN(data.areaSegments, 10),
                  data.totalUsers,
                  _areaColors,
                ),
                const SizedBox(height: 24),

                // 性別
                _buildSectionTitle('性別', Icons.wc_rounded),
                const SizedBox(height: 12),
                _buildSegmentBars(
                  data.genderSegments,
                  data.totalUsers,
                  _genderColors,
                ),
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

  Widget _buildSummaryCards(_SegmentData data) {
    final items = [
      _SummaryItem('全ユーザー', data.totalUsers, Icons.people_rounded, AppTheme.primaryColor),
      _SummaryItem('アクティブ', data.activeUsers, Icons.flash_on_rounded, AppTheme.success),
      _SummaryItem('休眠', data.inactiveUsers, Icons.snooze_rounded, AppTheme.warning),
      _SummaryItem('新規(7日)', data.newUsers, Icons.person_add_rounded, AppTheme.info),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  static const _experienceColors = {
    '1年未満': Colors.blue,
    '1-3年': Colors.teal,
    '3-5年': Colors.orange,
    '5年以上': Colors.red,
    '未設定': Colors.grey,
  };

  static const _genderColors = {
    '男性': Colors.blue,
    '女性': Colors.pink,
    '未設定': Colors.grey,
  };

  static const _defaultBarColor = Colors.blueGrey;

  Map<String, Color> get _areaColors => {};

  Map<String, int> _topN(Map<String, int> map, int n) {
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(n));
  }

  Widget _buildSegmentBars(
    Map<String, int> segments,
    int total,
    Map<String, Color> colorMap,
  ) {
    if (segments.isEmpty) {
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

    final effectiveTotal = total == 0 ? 1 : total;
    final colorKeys = colorMap.keys.toList();
    int colorIndex = 0;

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
        children: segments.entries.map((entry) {
          Color color;
          if (colorMap.containsKey(entry.key)) {
            color = colorMap[entry.key]!;
          } else if (colorMap.isEmpty) {
            // エリア用: 色を順番に割り当て
            final fallbackColors = [
              Colors.blue, Colors.teal, Colors.orange, Colors.purple,
              Colors.red, Colors.green, Colors.indigo, Colors.amber,
              Colors.cyan, Colors.deepOrange,
            ];
            color = fallbackColors[colorIndex % fallbackColors.length];
            colorIndex++;
          } else {
            color = _defaultBarColor;
          }

          final percent = (entry.value / effectiveTotal * 100).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${entry.value}人 ($percent%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

class _SegmentData {
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int newUsers;
  final Map<String, int> experienceSegments;
  final Map<String, int> areaSegments;
  final Map<String, int> genderSegments;

  _SegmentData({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.newUsers,
    required this.experienceSegments,
    required this.areaSegments,
    required this.genderSegments,
  });
}

class _SummaryItem {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  _SummaryItem(this.label, this.count, this.icon, this.color);
}
