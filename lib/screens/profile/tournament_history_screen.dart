import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../tournament/tournament_detail_screen.dart';

/// 参加大会履歴画面
class TournamentHistoryScreen extends StatelessWidget {
  const TournamentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('参加大会履歴')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('参加大会履歴')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadTournaments(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final tournaments = snapshot.data ?? [];
          if (tournaments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('まだ大会に参加していません',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = tournaments[index];
              return _buildTournamentCard(context, t);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadTournaments(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final result = <Map<String, dynamic>>[];

    // 主催した大会
    final organized = await firestore
        .collection('tournaments')
        .where('organizerId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .get();

    for (final doc in organized.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      data['role'] = '主催';
      result.add(data);
    }

    // エントリーした大会を検索
    final allTournaments = await firestore
        .collection('tournaments')
        .orderBy('date', descending: true)
        .limit(100)
        .get();

    for (final doc in allTournaments.docs) {
      if (result.any((r) => r['id'] == doc.id)) continue;

      final entries = await firestore
          .collection('tournaments')
          .doc(doc.id)
          .collection('entries')
          .where('enteredBy', isEqualTo: uid)
          .limit(1)
          .get();

      if (entries.docs.isNotEmpty) {
        final data = doc.data();
        data['id'] = doc.id;
        data['role'] = '参加';
        result.add(data);
      }
    }

    // 日付でソート
    result.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    return result;
  }

  Widget _buildTournamentCard(BuildContext context, Map<String, dynamic> t) {
    final title = (t['title'] ?? t['name'] ?? '大会') as String;
    final date = (t['date'] ?? '') as String;
    final location = (t['location'] ?? t['venue'] ?? '') as String;
    final status = (t['status'] ?? '') as String;
    final role = (t['role'] ?? '') as String;
    final type = (t['type'] ?? '') as String;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: t))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTag(role, role == '主催' ? AppTheme.primaryColor : AppTheme.accentColor),
                const SizedBox(width: 6),
                _buildTag(status, status == '終了' ? AppTheme.textSecondary : AppTheme.success),
                if (type.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildTag(type, AppTheme.warning),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            if (date.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(date, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(location,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ],
        ),
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
}
