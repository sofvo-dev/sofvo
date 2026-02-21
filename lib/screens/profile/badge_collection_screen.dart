import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// バッジコレクション全画面表示
class BadgeCollectionScreen extends StatelessWidget {
  const BadgeCollectionScreen({super.key});

  static const _badges = [
    _Badge('初参加', Icons.flag_rounded, Color(0xFF4CAF50), 'tournamentsPlayed', 1,
        '初めて大会に参加する'),
    _Badge('5大会参加', Icons.emoji_events_rounded, Color(0xFF2196F3), 'tournamentsPlayed', 5,
        '5つの大会に参加する'),
    _Badge('10大会参加', Icons.emoji_events_rounded, Color(0xFF9C27B0), 'tournamentsPlayed', 10,
        '10の大会に参加する'),
    _Badge('20大会参加', Icons.emoji_events_rounded, Color(0xFF3F51B5), 'tournamentsPlayed', 20,
        '20の大会に参加する'),
    _Badge('初優勝', Icons.military_tech_rounded, Color(0xFFFF9800), 'championships', 1,
        '大会で初めて優勝する'),
    _Badge('3回優勝', Icons.military_tech_rounded, Color(0xFFF44336), 'championships', 3,
        '大会で3回優勝する'),
    _Badge('5回優勝', Icons.military_tech_rounded, Color(0xFFE91E63), 'championships', 5,
        '大会で5回優勝する'),
    _Badge('100Pt達成', Icons.star_rounded, Color(0xFFFFC107), 'totalPoints', 100,
        '通算100ポイントを達成する'),
    _Badge('500Pt達成', Icons.star_rounded, Color(0xFFFF5722), 'totalPoints', 500,
        '通算500ポイントを達成する'),
    _Badge('1000Pt達成', Icons.diamond_rounded, Color(0xFFE91E63), 'totalPoints', 1000,
        '通算1000ポイントを達成する'),
    _Badge('ガジェット5個', Icons.devices_other_rounded, Color(0xFF00BCD4), 'gadgetCount', 5,
        'ガジェットを5個登録する'),
    _Badge('フォロワー10', Icons.people_rounded, Color(0xFF795548), 'followersCount', 10,
        'フォロワーが10人になる'),
    _Badge('フォロワー50', Icons.people_rounded, Color(0xFF607D8B), 'followersCount', 50,
        'フォロワーが50人になる'),
    _Badge('投稿10件', Icons.article_rounded, Color(0xFF009688), 'postsCount', 10,
        '投稿を10件する'),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('バッジコレクション')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('バッジコレクション')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final stats = data['stats'] is Map<String, dynamic>
              ? data['stats'] as Map<String, dynamic>
              : <String, dynamic>{};

          final values = {
            'tournamentsPlayed': _intVal(stats['tournamentsPlayed']),
            'championships': _intVal(stats['championships']),
            'totalPoints': _intVal(data['totalPoints']),
            'gadgetCount': _intVal(data['gadgetCount']),
            'followersCount': _intVal(data['followersCount']),
            'postsCount': _intVal(data['postsCount']),
          };

          final earned = _badges.where((b) => (values[b.statKey] ?? 0) >= b.threshold).length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('$earned / ${_badges.length}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('獲得済みバッジ',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _badges.length,
                  itemBuilder: (context, index) {
                    final badge = _badges[index];
                    final current = values[badge.statKey] ?? 0;
                    final isEarned = current >= badge.threshold;

                    return GestureDetector(
                      onTap: () => _showBadgeDetail(context, badge, current, isEarned),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isEarned ? Colors.white : Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isEarned
                                ? badge.color.withValues(alpha: 0.4)
                                : Colors.grey[200]!,
                            width: isEarned ? 2 : 1,
                          ),
                          boxShadow: isEarned
                              ? [BoxShadow(color: badge.color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isEarned
                                    ? badge.color.withValues(alpha: 0.12)
                                    : Colors.grey[200],
                                border: isEarned
                                    ? Border.all(color: badge.color.withValues(alpha: 0.3), width: 2.5)
                                    : null,
                              ),
                              child: Icon(badge.icon,
                                  color: isEarned ? badge.color : Colors.grey[400], size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(badge.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                                  color: isEarned ? AppTheme.textPrimary : AppTheme.textHint,
                                ),
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (!isEarned) ...[
                              const SizedBox(height: 4),
                              Text('$current/${badge.threshold}',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, _Badge badge, int current, bool earned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned
                    ? badge.color.withValues(alpha: 0.12)
                    : Colors.grey[200],
              ),
              child: Icon(badge.icon,
                  color: earned ? badge.color : Colors.grey[400], size: 40),
            ),
            const SizedBox(height: 16),
            Text(badge.name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: earned ? badge.color : AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(badge.description,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (earned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('獲得済み',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
              )
            else
              Column(
                children: [
                  LinearProgressIndicator(
                    value: current / badge.threshold,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(badge.color),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text('進捗: $current / ${badge.threshold}',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  int _intVal(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }
}

class _Badge {
  final String name;
  final IconData icon;
  final Color color;
  final String statKey;
  final int threshold;
  final String description;
  const _Badge(this.name, this.icon, this.color, this.statKey, this.threshold, this.description);
}
