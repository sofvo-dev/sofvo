import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // デモ：開催予定の大会
  final List<Map<String, dynamic>> _upcoming = [
    {
      'name': '第5回 世田谷カップ',
      'date': '2026/02/22',
      'dateLabel': '2/22（土）',
      'time': '9:00 - 17:00',
      'venue': '世田谷区総合体育館',
      'status': '参加確定',
      'teamName': 'サンダース',
      'format': '6人制',
      'daysLeft': 8,
    },
    {
      'name': '春のソフトバレー大会',
      'date': '2026/03/15',
      'dateLabel': '3/15（土）',
      'time': '10:00 - 18:00',
      'venue': '渋谷区スポーツセンター',
      'status': 'エントリー済',
      'teamName': 'サンダース',
      'format': '4人制',
      'daysLeft': 29,
    },
    {
      'name': '目黒区ソフトバレー交流戦',
      'date': '2026/03/22',
      'dateLabel': '3/22（日）',
      'time': '9:00 - 16:00',
      'venue': '目黒区立体育館',
      'status': 'エントリー済',
      'teamName': 'フェニックス',
      'format': '6人制',
      'daysLeft': 36,
    },
  ];

  // デモ：過去の大会
  final List<Map<String, dynamic>> _past = [
    {
      'name': '年末バレーボール祭り',
      'date': '2024/12/23',
      'dateLabel': '12/23（月）',
      'time': '9:00 - 17:00',
      'venue': '港区スポーツセンター',
      'teamName': 'サンダース',
      'format': '6人制',
      'result': '優勝',
      'resultIcon': Icons.military_tech,
      'resultColor': AppTheme.accentColor,
    },
    {
      'name': '初心者歓迎！ミックスバレー',
      'date': '2025/02/22',
      'dateLabel': '2/22（土）',
      'time': '10:00 - 16:00',
      'venue': '渋谷区スポーツセンター',
      'teamName': 'フェニックス',
      'format': '4人制',
      'result': '準優勝',
      'resultIcon': Icons.star,
      'resultColor': AppTheme.primaryColor,
    },
    {
      'name': '区民バレーボール選手権 2025',
      'date': '2025/06/08',
      'dateLabel': '6/8（日）',
      'time': '9:00 - 18:00',
      'venue': '世田谷区総合体育館',
      'teamName': 'サンダース',
      'format': '6人制',
      'result': 'ベスト8',
      'resultIcon': Icons.emoji_events_outlined,
      'resultColor': AppTheme.textSecondary,
    },
    {
      'name': '秋のソフトバレーフェス',
      'date': '2025/10/12',
      'dateLabel': '10/12（日）',
      'time': '10:00 - 17:00',
      'venue': '品川区立体育館',
      'teamName': 'サンダース',
      'format': '6人制',
      'result': '3位',
      'resultIcon': Icons.star_outline,
      'resultColor': AppTheme.info,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('予定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('フィルター機能は準備中です')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upcoming, size: 18),
                  const SizedBox(width: 6),
                  Text('開催予定 ${_upcoming.length}'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 6),
                  Text('過去の大会 ${_past.length}'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTab(),
          _buildPastTab(),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 開催予定タブ
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildUpcomingTab() {
    if (_upcoming.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined,
                size: 80, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('参加予定の大会はありません',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('大会を検索してエントリーしましょう！',
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // 月ごとにグルーピング
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final t in _upcoming) {
      final date = t['date'] as String;
      final parts = date.split('/');
      final monthKey = '${parts[0]}年${int.parse(parts[1])}月';
      grouped.putIfAbsent(monthKey, () => []).add(t);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 直近の大会ハイライト
        if (_upcoming.isNotEmpty) ...[
          _buildNextTournamentCard(_upcoming.first),
          const SizedBox(height: 20),
        ],

        // 月別一覧
        ...grouped.entries.expand((entry) => [
              Row(
                children: [
                  Icon(Icons.calendar_month,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry.value.length}件',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...entry.value.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildUpcomingCard(t),
                  )),
              const SizedBox(height: 8),
            ]),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 次の大会ハイライトカード
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildNextTournamentCard(Map<String, dynamic> t) {
    final daysLeft = t['daysLeft'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'あと${daysLeft}日',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                '次の大会',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            t['name'] as String,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '${t['dateLabel']}  ${t['time']}',
                style: const TextStyle(
                    fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                t['venue'] as String,
                style: const TextStyle(
                    fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '${t['teamName']}  ·  ${t['format']}',
                style: const TextStyle(
                    fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  t['status'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 開催予定カード
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildUpcomingCard(Map<String, dynamic> t) {
    final status = t['status'] as String;
    Color statusColor;
    switch (status) {
      case '参加確定':
        statusColor = AppTheme.success;
        break;
      case 'エントリー済':
        statusColor = AppTheme.warning;
        break;
      default:
        statusColor = AppTheme.primaryColor;
    }

    final dateLabel = t['dateLabel'] as String;
    final day = dateLabel.split('（')[0].split('/').last;
    final weekday =
        dateLabel.contains('（') ? '（${dateLabel.split('（')[1]}' : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color:
                    AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    weekday,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t['name'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['time'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.sports_volleyball,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['format'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(t['venue'] as String,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['teamName'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 過去の大会タブ
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPastTab() {
    if (_past.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: AppTheme.textHint),
            const SizedBox(height: 16),
            const Text('過去の大会はありません',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('大会に参加すると履歴がここに表示されます',
                style: TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // 戦績サマリー
    final totalGames = _past.length;
    final wins = _past.where((t) => t['result'] == '優勝').length;
    final podiums = _past
        .where((t) =>
            t['result'] == '優勝' ||
            t['result'] == '準優勝' ||
            t['result'] == '3位')
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 戦績サマリー
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                    '参加大会', '$totalGames', AppTheme.primaryColor),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
              ),
              Expanded(
                child:
                    _buildSummaryItem('優勝', '$wins', AppTheme.accentColor),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildSummaryItem(
                    '入賞', '$podiums', AppTheme.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 大会リスト
        ...List.generate(_past.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPastCard(_past[index]),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 過去の大会カード
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildPastCard(Map<String, dynamic> t) {
    final result = t['result'] as String;
    final resultColor = t['resultColor'] as Color;
    final resultIcon = t['resultIcon'] as IconData;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 結果アイコン
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(resultIcon, color: resultColor, size: 26),
            ),
            const SizedBox(width: 14),
            // 情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t['name'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(resultIcon,
                                size: 13, color: resultColor),
                            const SizedBox(width: 3),
                            Text(
                              result,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: resultColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['dateLabel'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.groups_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['teamName'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      Icon(Icons.sports_volleyball,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['format'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['venue'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
