import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'user_profile_screen.dart';

/// 通報管理画面（公式アカウント専用）
class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  String _filter = 'all'; // 'all', 'pending', 'resolved'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('通報管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // フィルターチップ
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('すべて', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('未対応', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('対応済み', 'resolved'),
              ],
            ),
          ),
          const Divider(height: 1),
          // レポート一覧
          Expanded(child: _buildReportList()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildReportList() {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true);

    if (_filter == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else if (_filter == 'resolved') {
      query = query.where('status', whereIn: ['resolved', 'dismissed']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 12),
                  Text('データの取得に失敗しました',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('${snapshot.error}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textHint),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  _filter == 'pending'
                      ? '未対応の通報はありません'
                      : _filter == 'resolved'
                          ? '対応済みの通報はありません'
                          : '通報はありません',
                  style: TextStyle(
                      fontSize: 15, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReportCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(
      BuildContext context, String reportId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'user';
    final reason = data['reason'] as String? ?? '不明';
    final status = data['status'] as String? ?? 'pending';
    final reporterId = data['reporterId'] as String? ?? '';
    final targetUserId = data['targetUserId'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: () => _showReportDetail(context, reportId, data),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: タイプ + ステータス
            Row(
              children: [
                _buildTypeBadge(type),
                const Spacer(),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            // 通報理由
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.report_outlined, size: 18, color: Colors.red.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reason,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 通報者・対象者
            _buildInfoRow(
                Icons.person_outline, '通報者', reporterId),
            if (targetUserId.isNotEmpty)
              _buildInfoRow(
                  Icons.person_off_outlined, '対象者', targetUserId),
            if (data['postId'] != null)
              _buildInfoRow(
                  Icons.article_outlined, '投稿ID', data['postId']),
            if (data['commentId'] != null)
              _buildInfoRow(
                  Icons.comment_outlined, 'コメントID', data['commentId']),
            const SizedBox(height: 8),
            // タイムスタンプ
            if (createdAt != null)
              Text(
                _formatDate(createdAt.toDate()),
                style: TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textHint),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final config = _typeConfig(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 4),
          Text(config.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: config.color)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    switch (status) {
      case 'resolved':
        bgColor = AppTheme.success.withValues(alpha: 0.1);
        textColor = AppTheme.success;
        label = '対応済み';
        break;
      case 'dismissed':
        bgColor = Colors.grey.shade100;
        textColor = AppTheme.textSecondary;
        label = '却下';
        break;
      default:
        bgColor = AppTheme.warning.withValues(alpha: 0.15);
        textColor = Colors.orange.shade800;
        label = '未対応';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  _TypeConfig _typeConfig(String type) {
    switch (type) {
      case 'post':
        return _TypeConfig(
            icon: Icons.article_rounded, label: '投稿', color: AppTheme.info);
      case 'comment':
        return _TypeConfig(
            icon: Icons.comment_rounded,
            label: 'コメント',
            color: Colors.teal);
      default:
        return _TypeConfig(
            icon: Icons.person_rounded,
            label: 'ユーザー',
            color: Colors.deepOrange);
    }
  }

  void _showReportDetail(
      BuildContext context, String reportId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'user';
    final reason = data['reason'] as String? ?? '不明';
    final status = data['status'] as String? ?? 'pending';
    final reporterId = data['reporterId'] as String? ?? '';
    final targetUserId = data['targetUserId'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // タイトル
              Row(
                children: [
                  _buildTypeBadge(type),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 20),
              // 通報理由
              const Text('通報理由',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(reason, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 20),
              // 詳細情報
              const Text('詳細',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              _buildDetailItem('通報者ID', reporterId, onTap: () {
                if (reporterId.isNotEmpty) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: reporterId)));
                }
              }),
              if (targetUserId.isNotEmpty)
                _buildDetailItem('対象ユーザーID', targetUserId, onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              UserProfileScreen(userId: targetUserId)));
                }),
              if (data['postId'] != null)
                _buildDetailItem('投稿ID', data['postId']),
              if (data['commentId'] != null)
                _buildDetailItem('コメントID', data['commentId']),
              if (createdAt != null)
                _buildDetailItem('通報日時', _formatDate(createdAt.toDate())),
              const SizedBox(height: 24),
              // アクションボタン
              if (status == 'pending') ...[
                const Text('アクション',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _updateStatus(ctx, reportId, 'resolved'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('対応済みにする'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateStatus(ctx, reportId, 'dismissed'),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('却下する'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                if (targetUserId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _freezeUser(ctx, reportId, targetUserId),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('ユーザーを凍結'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Center(
                  child: Text(
                    status == 'resolved' ? 'この通報は対応済みです' : 'この通報は却下されました',
                    style: TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: onTap != null ? AppTheme.info : AppTheme.textPrimary,
                  decoration:
                      onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext ctx, String reportId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (ctx.mounted) Navigator.pop(ctx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'resolved' ? '対応済みに更新しました' : '却下しました'),
            backgroundColor:
                newStatus == 'resolved' ? AppTheme.success : AppTheme.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('更新に失敗しました: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _freezeUser(
      BuildContext ctx, String reportId, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('ユーザーを凍結'),
        content: const Text('このユーザーのアカウントを凍結しますか？凍結するとログインできなくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('凍結する'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isFrozen': true,
          'frozenAt': FieldValue.serverTimestamp(),
        }),
        FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
          'status': 'resolved',
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);
      if (ctx.mounted) Navigator.pop(ctx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ユーザーを凍結し、通報を対応済みにしました'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('凍結に失敗しました: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _TypeConfig {
  final IconData icon;
  final String label;
  final Color color;
  const _TypeConfig(
      {required this.icon, required this.label, required this.color});
}
