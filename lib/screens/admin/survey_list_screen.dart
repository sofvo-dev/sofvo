import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'create_survey_screen.dart';
import 'survey_results_screen.dart';

/// アンケート管理画面（公式アカウント用）
class SurveyListScreen extends StatelessWidget {
  const SurveyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('アンケート管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateSurveyScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('surveys')
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
                  Icon(Icons.poll_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('アンケートはありません',
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('右下の＋ボタンから作成できます',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _SurveyCard(
                docId: doc.id,
                data: data,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurveyResultsScreen(
                      surveyId: doc.id,
                      surveyTitle: data['title'] as String? ?? '',
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _SurveyCard({
    required this.docId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final active = data['active'] == true;
    final responseCount = data['responseCount'] as int? ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().year}/${createdAt.toDate().month}/${createdAt.toDate().day}'
        : '';
    final questions = (data['questions'] as List<dynamic>?) ?? [];

    return Dismissible(
      key: ValueKey(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: active ? Colors.grey : AppTheme.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(active ? '終了' : '再開',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        await FirebaseFirestore.instance
            .collection('surveys')
            .doc(docId)
            .update({'active': !active});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(active ? 'アンケートを終了しました' : 'アンケートを再開しました'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: active ? AppTheme.textSecondary : AppTheme.success,
            ),
          );
        }
        return false; // Don't actually dismiss the item
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (active ? Colors.orange : Colors.grey)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.poll_rounded,
                      color: active ? Colors.orange : Colors.grey, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppTheme.success.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              active ? '配信中' : '終了',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: active ? AppTheme.success : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr  ・  ${questions.length}問  ・  $responseCount件回答',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
