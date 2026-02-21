import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../tournament/tournament_detail_screen.dart';

/// ブックマーク一覧画面
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ブックマーク')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('ブックマーク'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '大会'),
              Tab(text: 'メンバー募集'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BookmarkList(uid: uid, type: 'tournament'),
            _BookmarkList(uid: uid, type: 'recruitment'),
          ],
        ),
      ),
    );
  }
}

class _BookmarkList extends StatelessWidget {
  final String uid;
  final String type;

  const _BookmarkList({required this.uid, required this.type});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final bookmarks = snapshot.data?.docs ?? [];
        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  type == 'tournament'
                      ? 'ブックマークした大会はありません'
                      : 'ブックマークした募集はありません',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bookmarks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = bookmarks[index].data() as Map<String, dynamic>;
            return _buildBookmarkCard(context, data, bookmarks[index].reference);
          },
        );
      },
    );
  }

  Widget _buildBookmarkCard(
      BuildContext context, Map<String, dynamic> data, DocumentReference ref) {
    final title = (data['title'] ?? data['tournamentName'] ?? '---') as String;
    final date = (data['date'] ?? data['tournamentDate'] ?? '') as String;
    final location = (data['location'] ?? '') as String;
    final status = (data['status'] ?? '') as String;
    final alerts = data['alerts'] is List ? List<String>.from(data['alerts']) : <String>[];
    final targetId = (data['targetId'] ?? '') as String;

    return GestureDetector(
      onTap: () async {
        if (type == 'tournament' && targetId.isNotEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(targetId)
              .get();
          if (doc.exists && context.mounted) {
            final tData = doc.data()!;
            tData['id'] = doc.id;
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: tData)));
          }
        }
      },
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
                if (status.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status))),
                  ),
                  const SizedBox(width: 6),
                ],
                if (alerts.contains('deadline'))
                  _alertBadge('締切間近', AppTheme.error),
                if (alerts.contains('slots'))
                  _alertBadge('残りわずか', AppTheme.warning),
                const Spacer(),
                GestureDetector(
                  onTap: () => _confirmRemove(context, ref),
                  child: Icon(Icons.bookmark, color: AppTheme.primaryColor, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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

  Widget _alertBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case '募集中':
        return AppTheme.success;
      case '終了':
        return AppTheme.textSecondary;
      case '開催中':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _confirmRemove(BuildContext context, DocumentReference ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ブックマーク解除',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('このブックマークを解除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('解除'),
          ),
        ],
      ),
    );
  }
}
