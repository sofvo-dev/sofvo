import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

class RecruitmentManagementScreen extends StatefulWidget {
  const RecruitmentManagementScreen({super.key});

  @override
  State<RecruitmentManagementScreen> createState() =>
      _RecruitmentManagementScreenState();
}

class _RecruitmentManagementScreenState
    extends State<RecruitmentManagementScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final uid = _currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('メンバー募集管理')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('メンバー募集管理'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recruitments')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          if (snapshot.hasError) {
            return _buildEmptyState();
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          final active = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == '募集中';
          }).toList();

          final closed = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] != '募集中';
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ..._buildSection('募集中', active),
              if (active.isNotEmpty && closed.isNotEmpty)
                const SizedBox(height: 16),
              ..._buildSection('締切・終了', closed),
            ],
          );
        },
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
      String title, List<QueryDocumentSnapshot> items) {
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
      ...items.map((doc) {
        final r = doc.data() as Map<String, dynamic>;
        r['docId'] = doc.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecruitmentCard(r),
        );
      }),
    ];
  }

  Widget _buildRecruitmentCard(Map<String, dynamic> r) {
    final status = (r['status'] as String?) ?? '募集中';
    final isActive = status == '募集中';
    final statusColor = isActive ? AppTheme.success : AppTheme.textSecondary;
    final needed = (r['needed'] as int?) ?? 0;
    final approved = (r['approvedCount'] as int?) ?? 0;
    final pending = (r['pendingCount'] as int?) ?? 0;

    return GestureDetector(
      onTap: () => _showRecruitmentDetail(r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: pending > 0 && isActive
                  ? AppTheme.accentColor.withValues(alpha: 0.5)
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
                        ? AppTheme.accentColor.withValues(alpha: 0.12)
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
                        Text((r['title'] as String?) ?? '',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text((r['tournament'] as String?) ?? '',
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
                _buildInfoChip(Icons.groups_outlined, (r['team'] as String?) ?? ''),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.people, '$needed人募集'),
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
                                      .withValues(alpha: 0.12),
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
                      Text((r['deadline'] as String?) ?? '',
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
    final docId = r['docId'] as String?;
    if (docId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recruitments')
                  .doc(docId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final isActive = data['status'] == '募集中';

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
                      Text((data['title'] as String?) ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _buildTag((data['status'] as String?) ?? '',
                            isActive ? AppTheme.success : AppTheme.textSecondary),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.emoji_events, '大会',
                          (data['tournament'] as String?) ?? ''),
                      _buildDetailRow(Icons.groups, 'チーム',
                          (data['team'] as String?) ?? ''),
                      _buildDetailRow(Icons.people, '募集人数',
                          '${data['needed'] ?? 0}人'),
                      _buildDetailRow(Icons.timer_outlined, '締切',
                          (data['deadline'] as String?) ?? ''),
                      if (((data['message'] as String?) ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(data['message'] as String,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                  height: 1.5)),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // 応募者一覧（サブコレクション）
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('recruitments')
                            .doc(docId)
                            .collection('applicants')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, appSnap) {
                          final applicants = appSnap.data?.docs ?? [];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                                ...applicants.map((aDoc) {
                                  final a = aDoc.data() as Map<String, dynamic>;
                                  final aStatus = (a['status'] as String?) ?? '承認待ち';
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
                                  final name = (a['name'] as String?) ?? 'ユーザー';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: aStatus == '承認待ち' && isActive
                                          ? AppTheme.accentColor.withValues(alpha: 0.04)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: aStatus == '承認待ち' && isActive
                                              ? AppTheme.accentColor.withValues(alpha: 0.3)
                                              : Colors.grey[200]!),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: AppTheme.primaryColor
                                                  .withValues(alpha: 0.12),
                                              child: Text(
                                                  name.isNotEmpty ? name[0] : '?',
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
                                                  Text(name,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                      '競技歴 ${a['experience'] ?? ''}',
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
                                                  onPressed: () async {
                                                    await aDoc.reference.update({'status': '拒否'});
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.error,
                                                    side: BorderSide(
                                                        color: AppTheme.error
                                                            .withValues(alpha: 0.5)),
                                                  ),
                                                  child: const Text('見送り'),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    await aDoc.reference.update({'status': '承認済'});
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(SnackBar(
                                                              content: Text(
                                                                  '$nameさんを承認しました！'),
                                                              backgroundColor:
                                                                  AppTheme.success));
                                                    }
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
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      if (data['status'] == '募集中')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('recruitments')
                                  .doc(docId)
                                  .update({'status': '締切'});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                        content: Text('募集を締め切りました'),
                                        backgroundColor: AppTheme.success));
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: BorderSide(
                                  color: AppTheme.error.withValues(alpha: 0.5)),
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
          },
        );
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
        color: color.withValues(alpha: 0.1),
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
