import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// フィードバック管理画面（管理者用）
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['すべて', '要望', 'バグ', 'その他'];
  static const _categoryFilters = [null, '要望', 'バグ報告', 'その他'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
        title: const Text('フィードバック管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categoryFilters
            .map((filter) => _FeedbackList(categoryFilter: filter))
            .toList(),
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final String? categoryFilter;

  const _FeedbackList({this.categoryFilter});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('feedback')
        .orderBy('createdAt', descending: true);

    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.feedback_outlined,
                    size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text('フィードバックはありません',
                    style:
                        TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _FeedbackCard(docId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _FeedbackCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _FeedbackCard({required this.docId, required this.data});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final userName = widget.data['userName'] as String? ?? '不明なユーザー';
    final category = widget.data['category'] as String? ?? 'その他';
    final content = widget.data['content'] as String? ?? '';
    final status = widget.data['status'] as String? ?? 'pending';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final screenshotUrl = widget.data['screenshotUrl'] as String? ?? '';
    final isResolved = status == 'resolved';

    final dateStr = createdAt != null
        ? '${createdAt.toDate().year}/${createdAt.toDate().month}/${createdAt.toDate().day}'
        : '';

    Color categoryColor;
    switch (category) {
      case '要望':
        categoryColor = AppTheme.info;
        break;
      case 'バグ報告':
        categoryColor = AppTheme.error;
        break;
      default:
        categoryColor = AppTheme.textSecondary;
    }

    return Dismissible(
      key: ValueKey(widget.docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: isResolved ? Colors.grey : AppTheme.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isResolved
                    ? Icons.replay
                    : Icons.check_circle_outline,
                color: Colors.white,
                size: 28),
            const SizedBox(height: 4),
            Text(isResolved ? '未対応に戻す' : '対応済み',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final newStatus = isResolved ? 'pending' : 'resolved';
        await FirebaseFirestore.instance
            .collection('feedback')
            .doc(widget.docId)
            .update({'status': newStatus});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(isResolved ? '未対応に戻しました' : '対応済みにしました'),
              backgroundColor:
                  isResolved ? AppTheme.warning : AppTheme.success,
            ),
          );
        }
        return false;
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // カテゴリバッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(category,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: categoryColor)),
                    ),
                    const SizedBox(width: 8),
                    // ステータスバッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isResolved
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isResolved ? '対応済み' : '未対応',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isResolved ? AppTheme.success : Colors.orange,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(userName,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary),
                  maxLines: _expanded ? null : 2,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (_expanded && screenshotUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      screenshotUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(Icons.broken_image,
                              color: AppTheme.textHint),
                        ),
                      ),
                    ),
                  ),
                ],
                if (!_expanded && content.length > 80) ...[
                  const SizedBox(height: 4),
                  Text('タップで全文表示',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
