import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// ポイント獲得履歴画面
class PointHistoryScreen extends StatelessWidget {
  const PointHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ポイント履歴')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('ポイント履歴')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('pointHistory')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('まだポイント履歴がありません',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('大会に参加してポイントを獲得しよう！',
                      style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
          }

          // 合計ポイント計算
          int totalEarned = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalEarned += _safeInt(data['totalEarned']);
          }

          return Column(
            children: [
              // サマリーヘッダー
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('獲得ポイント合計',
                              style: TextStyle(fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$totalEarned',
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 4),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Text('pt', style: TextStyle(fontSize: 16, color: Colors.white70)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildHistoryCard(data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final tournamentName = (data['tournamentName'] ?? '') as String;
    final date = (data['date'] ?? '') as String;
    final rank = data['rank'] as int?;
    final rankPoints = _safeInt(data['rankPoints']);
    final totalEarned = _safeInt(data['totalEarned']);
    final teamCount = _safeInt(data['teamCount']);

    final rankNames = {1: '優勝', 2: '準優勝', 3: '3位'};
    final rankLabel = rank != null ? rankNames[rank] ?? '参加' : '参加';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大会名 + 日付
          Row(
            children: [
              Expanded(
                child: Text(tournamentName.isEmpty ? '大会' : tournamentName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              if (date.isNotEmpty)
                Text(date, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          // タグ
          Row(
            children: [
              _buildTag(rankLabel, rank == 1 ? Colors.amber : rank == 2 ? const Color(0xFFC0C0C0) : AppTheme.primaryColor),
              if (teamCount > 0) ...[
                const SizedBox(width: 6),
                _buildTag('$teamCountチーム', AppTheme.textSecondary),
              ],
            ],
          ),
          const Divider(height: 16),
          // ポイント内訳
          if (rankPoints > 0)
            _buildPointDetail('順位ポイント ($rankLabel)', '+$rankPoints'),
          const SizedBox(height: 4),
          // 合計
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('+${totalEarned}pt',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointDetail(String label, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
          Text(points, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }
}
