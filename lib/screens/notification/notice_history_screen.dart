import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 配信履歴画面（公式アカウント用）
class NoticeHistoryScreen extends StatelessWidget {
  const NoticeHistoryScreen({super.key});

  static String _formatScheduledAt(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${p(d.month)}/${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  static const _noticeTypeMap = <String, Map<String, dynamic>>{
    'info': {'icon': Icons.info_outline, 'color': 0xFF1B3A5C, 'label': 'お知らせ'},
    'release': {'icon': Icons.campaign, 'color': 0xFFC4A962, 'label': 'リリース'},
    'update': {'icon': Icons.update, 'color': 0xFF1565C0, 'label': 'アップデート'},
    'maintenance': {'icon': Icons.build, 'color': 0xFFF9A825, 'label': 'メンテナンス'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('配信履歴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildScheduledSection(context),
          Expanded(child: _buildHistoryList(context)),
        ],
      ),
    );
  }

  Widget _buildScheduledSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .where('status', isEqualTo: 'scheduled')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        // client-side sort by scheduledAt ascending
        final sorted = List<QueryDocumentSnapshot>.from(docs);
        sorted.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          final at = (ad['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bt = (bd['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        });
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('配信予約 (${sorted.length})',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor)),
                ],
              ),
              const SizedBox(height: 8),
              ...sorted.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? '';
                final scheduledAt = data['scheduledAt'] as Timestamp?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(_formatScheduledAt(scheduledAt),
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                        tooltip: '予約を取消',
                        onPressed: () async {
                          final ok = await _confirmCancelSchedule(context);
                          if (ok == true) {
                            await doc.reference.delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('配信予約を取消しました'),
                                    backgroundColor: AppTheme.success),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmCancelSchedule(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('配信予約を取消',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('この配信予約を取消しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('取消する', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('配信履歴はありません',
                      style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'info';
              final meta = _noticeTypeMap[type] ?? _noticeTypeMap['info']!;
              final icon = meta['icon'] as IconData;
              final color = Color(meta['color'] as int);
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final pinned = data['pinned'] == true;
              final link = data['link'] as String?;

              return Dismissible(
                key: ValueKey(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => _deleteNotice(context, doc.id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (pinned) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.push_pin, size: 14, color: AppTheme.textSecondary),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (link != null && link.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.link, size: 12, color: color),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      link,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(createdAt),
                              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('お知らせを削除',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('このお知らせを削除しますか？\n削除すると元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  void _deleteNotice(BuildContext context, String docId) {
    FirebaseFirestore.instance.collection('notices').doc(docId).delete().then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お知らせを削除しました'), backgroundColor: AppTheme.success),
        );
      }
    }).catchError((e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${date.year}/${date.month}/${date.day}';
  }
}
