import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// ユーザー統計ダッシュボード（公式アカウント専用）
class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ユーザー統計'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'サービス全体の統計',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _StatCard(
                    icon: Icons.people_rounded,
                    label: '総ユーザー数',
                    color: AppTheme.primaryColor,
                    countFuture: _getCollectionCount('users'),
                  ),
                  _StatCard(
                    icon: Icons.emoji_events_rounded,
                    label: '総大会数',
                    color: AppTheme.accentColor,
                    countFuture: _getCollectionCount('tournaments'),
                  ),
                  _StatCard(
                    icon: Icons.article_rounded,
                    label: '総投稿数',
                    color: Colors.teal,
                    countFuture: _getCollectionCount('posts'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getCollectionCount(String collection) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Future<int> countFuture;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.countFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: countFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                );
              }
              return Text(
                '${snapshot.data ?? 0}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              );
            },
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
      ),
    );
  }
}
