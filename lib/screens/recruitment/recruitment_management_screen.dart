import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class RecruitmentManagementScreen extends StatefulWidget {
  const RecruitmentManagementScreen({super.key});

  @override
  State<RecruitmentManagementScreen> createState() =>
      _RecruitmentManagementScreenState();
}

class _RecruitmentManagementScreenState
    extends State<RecruitmentManagementScreen> {
  final List<Map<String, dynamic>> _recruitments = [
    {
      'title': '3/8 区民選手権 メンバー募集',
      'tournament': '区民バレーボール選手権',
      'team': 'サンダース',
      'needed': 1,
      'status': '募集中',
      'deadline': '2025/03/01',
      'message': 'あと1人足りません！一緒に出ましょう！',
      'applicants': [
        {'name': 'ゆうた', 'experience': '3〜5年', 'status': '承認待ち'},
        {'name': 'あきら', 'experience': '10年以上', 'status': '承認待ち'},
      ],
    },
    {
      'title': '4/12 春の親善大会 助っ人募集',
      'tournament': '春の親善バレーボール大会',
      'team': 'サンダース',
      'needed': 2,
      'status': '募集中',
      'deadline': '2025/04/05',
      'message': '楽しくバレーしましょう！初心者大歓迎です。',
      'applicants': [
        {'name': 'けんた', 'experience': '1〜3年', 'status': '承認済'},
        {'name': 'まさと', 'experience': '3〜5年', 'status': '承認待ち'},
        {'name': 'そうた', 'experience': '1年未満', 'status': '拒否'},
      ],
    },
    {
      'title': '2/22 ミックスバレー メンバー募集',
      'tournament': '初心者歓迎！ミックスバレー',
      'team': 'フェニックス',
      'needed': 1,
      'status': '締切',
      'deadline': '2025/02/15',
      'message': '',
      'applicants': [
        {'name': 'りく', 'experience': '1年未満', 'status': '承認済'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('メンバー募集管理'),
      ),
      body: _recruitments.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ..._buildSection('募集中',
                    _recruitments.where((r) => r['status'] == '募集中').toList()),
                const SizedBox(height: 16),
                ..._buildSection('締切・終了',
                    _recruitments.where((r) => r['status'] != '募集中').toList()),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 80, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('メンバー募集はありません',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('大会詳細画面から\n「メンバー募集する」で作成できます',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _buildSection(
      String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return [];
    return [
      Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${items.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ...items.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecruitmentCard(r),
          )),
    ];
  }

  Widget _buildRecruitmentCard(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final isActive = status == '募集中';
    final statusColor = isActive ? AppTheme.success : AppTheme.textSecondary;
    final applicants = r['applicants'] as List<Map<String, dynamic>>;
    final approved =
        applicants.where((a) => a['status'] == '承認済').length;
    final pending =
        applicants.where((a) => a['status'] == '承認待ち').length;
    final needed = r['needed'] as int;

    return GestureDetector(
      onTap: () => _showRecruitmentDetail(r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: pending > 0 && isActive
                  ? AppTheme.accentColor.withOpacity(0.5)
                  : Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isActive
                        ? AppTheme.accentColor.withOpacity(0.12)
                        : Colors.grey[100],
                    child: Icon(Icons.person_search,
                        color: isActive
                            ? AppTheme.accentColor
                            : AppTheme.textSecondary,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['title'] as String,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(r['tournament'] as String,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  _buildTag(status, statusColor),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                _buildInfoChip(Icons.groups_outlined, r['team'] as String),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.people, '${r['needed']}人募集'),
              ]),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('承認 $approved/$needed人',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                            if (pending > 0 && isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor
                                      .withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text('$pending件 未対応',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentColor)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: needed > 0 ? approved / needed : 0,
                            backgroundColor: Colors.grey[200],
                            color: approved >= needed
                                ? AppTheme.success
                                : AppTheme.primaryColor,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('締切',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary)),
                      Text(r['deadline'] as String,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecruitmentDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final applicants =
              r['applicants'] as List<Map<String, dynamic>>;
          final isActive = r['status'] == '募集中';

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) {
              return SingleChildScrollView(
                controller: scrollCtrl,
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
                    Text(r['title'] as String,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _buildTag(r['status'] as String,
                          isActive ? AppTheme.success : AppTheme.textSecondary),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.emoji_events, '大会',
                        r['tournament'] as String),
                    _buildDetailRow(Icons.groups, 'チーム',
                        r['team'] as String),
                    _buildDetailRow(Icons.people, '募集人数',
                        '${r['needed']}人'),
                    _buildDetailRow(Icons.timer_outlined, '締切',
                        r['deadline'] as String),
                    if ((r['message'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(r['message'] as String,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                                height: 1.5)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Text('応募者',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${applicants.length}人',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (applicants.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('まだ応募はありません',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      )
                    else
                      ...applicants.map((a) {
                        final aStatus = a['status'] as String;
                        Color aBadgeColor;
                        switch (aStatus) {
                          case '承認済':
                            aBadgeColor = AppTheme.success;
                            break;
                          case '拒否':
                            aBadgeColor = AppTheme.error;
                            break;
                          default:
                            aBadgeColor = AppTheme.accentColor;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: aStatus == '承認待ち' && isActive
                                ? AppTheme.accentColor.withOpacity(0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: aStatus == '承認待ち' && isActive
                                    ? AppTheme.accentColor.withOpacity(0.3)
                                    : Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.primaryColor
                                        .withOpacity(0.12),
                                    child: Text(
                                        (a['name'] as String)[0],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a['name'] as String,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '競技歴 ${a['experience']}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme
                                                    .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  _buildTag(aStatus, aBadgeColor),
                                ],
                              ),
                              if (aStatus == '承認待ち' && isActive) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setSheetState(() =>
                                              a['status'] = '拒否');
                                          setState(() {});
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.error,
                                          side: BorderSide(
                                              color: AppTheme.error
                                                  .withOpacity(0.5)),
                                        ),
                                        child: const Text('見送り'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setSheetState(() =>
                                              a['status'] = '承認済');
                                          setState(() {});
                                          ScaffoldMessenger.of(
                                                  this.context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      '${a['name']}さんを承認しました！'),
                                                  backgroundColor:
                                                      AppTheme.success));
                                        },
                                        child: const Text('承認する'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                    if (isActive)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() => r['status'] = '締切');
                            setState(() {});
                            ScaffoldMessenger.of(this.context)
                                .showSnackBar(const SnackBar(
                                    content: Text('募集を締め切りました'),
                                    backgroundColor: AppTheme.success));
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: BorderSide(
                                color: AppTheme.error.withOpacity(0.5)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('募集を締め切る',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}
