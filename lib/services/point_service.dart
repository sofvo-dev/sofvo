import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// ポイント計算・付与サービス
class PointService {
  static final _firestore = FirebaseFirestore.instance;

  // ━━━ 順位係数（チーム数 × 係数 = ポイント） ━━━
  static double _rankMultiplier(int rank) {
    switch (rank) {
      case 1: return 3.0;   // 優勝
      case 2: return 2.0;   // 準優勝
      case 3: return 1.5;   // 3位
      case 4: return 1.2;   // 4位
      default: return 1.0;  // それ以外 = 参加ポイント
    }
  }

  /// 順位ポイントを計算
  static int calculateRankPoints(int teamCount, int rank) {
    return (teamCount * _rankMultiplier(rank)).round();
  }

  /// 主催者ボーナスを計算
  static int calculateOrganizerBonus(int teamCount) {
    return (teamCount * 0.3).round();
  }

  /// ストリークボーナスを計算
  static int calculateStreakBonus(int currentStreak) {
    if (currentStreak >= 4) return 15;
    if (currentStreak >= 3) return 10;
    if (currentStreak >= 2) return 5;
    return 0;
  }

  /// 大会のポイント表（UI表示用）を取得
  static Map<String, int> getPointTable(int teamCount) {
    return {
      '優勝': calculateRankPoints(teamCount, 1),
      '準優勝': calculateRankPoints(teamCount, 2),
      '3位': calculateRankPoints(teamCount, 3),
      '4位': calculateRankPoints(teamCount, 4),
      '参加': calculateRankPoints(teamCount, 5),
      '主催者': calculateOrganizerBonus(teamCount),
    };
  }

  /// 大会終了時にポイントを付与する
  /// Cloud Functionsでも同様のロジックを持つが、クライアント側でも実行可能
  static Future<void> awardTournamentPoints({
    required String tournamentId,
  }) async {
    final tournamentRef = _firestore.collection('tournaments').doc(tournamentId);
    final tournamentDoc = await tournamentRef.get();
    if (!tournamentDoc.exists) return;

    final tournament = tournamentDoc.data()!;

    // 二重付与防止
    if (tournament['pointsAwarded'] == true) return;

    final teamCount = (tournament['currentTeams'] as num?)?.toInt() ?? 0;
    if (teamCount == 0) return;

    final organizerId = tournament['organizerId'] as String? ?? '';
    final tournamentName = tournament['title'] as String? ?? tournament['name'] as String? ?? '';

    // エントリーデータ取得
    final entries = await tournamentRef.collection('entries').get();

    // 全参加者のUID → チームID マッピング
    final userTeamMap = <String, String>{};
    final teamUserMap = <String, Set<String>>{};
    for (final doc in entries.docs) {
      final data = doc.data();
      final teamId = data['teamId'] as String? ?? doc.id;
      final uids = <String>{};

      // memberUids から取得（通常エントリー）
      final memberUids = data['memberUids'];
      if (memberUids is List) {
        for (final uid in memberUids) {
          if (uid is String && uid.isNotEmpty) {
            uids.add(uid);
            userTeamMap[uid] = teamId;
          }
        }
      }

      // leaderUid から取得（CSV登録でも設定される場合がある）
      final leaderUid = data['leaderUid'] as String?;
      if (leaderUid != null && leaderUid.isNotEmpty) {
        uids.add(leaderUid);
        userTeamMap[leaderUid] = teamId;
      }

      // enteredBy から取得
      final enteredBy = data['enteredBy'] as String?;
      if (enteredBy != null && enteredBy.isNotEmpty) {
        uids.add(enteredBy);
        userTeamMap[enteredBy] = teamId;
      }
      teamUserMap[teamId] = uids;
    }

    // ━━━ 順位情報取得 ━━━
    final teamRanks = <String, int>{};

    // ブラケット（決勝トーナメント）から順位取得
    final brackets = await tournamentRef.collection('brackets').get();
    if (brackets.docs.isNotEmpty) {
      for (final bDoc in brackets.docs) {
        final matches = await bDoc.reference.collection('matches')
            .where('status', isEqualTo: 'completed')
            .get();

        // 決勝戦を見つける（round: 'final' or 'final_1st'）
        final finalMatch = matches.docs.where((m) {
          final round = m.data()['round'] as String? ?? '';
          return round == 'final' || round == 'final_1st';
        }).firstOrNull;

        if (finalMatch != null) {
          final fm = finalMatch.data();
          final result = fm['result'] as Map<String, dynamic>? ?? {};
          final winnerId = result['winner'] as String? ?? '';
          final teamAId = fm['teamAId'] as String? ?? '';
          final teamBId = fm['teamBId'] as String? ?? '';

          if (winnerId.isNotEmpty) {
            teamRanks[winnerId] = 1;
            final loserId = winnerId == teamAId ? teamBId : teamAId;
            if (loserId.isNotEmpty) teamRanks[loserId] = 2;
          }
        }

        // 3位決定戦（round: 'third_place' or 'final_3rd'）
        final thirdPlaceMatch = matches.docs.where((m) {
          final round = m.data()['round'] as String? ?? '';
          return round == 'third_place' || round == 'final_3rd';
        }).firstOrNull;

        if (thirdPlaceMatch != null) {
          final tm = thirdPlaceMatch.data();
          final result = tm['result'] as Map<String, dynamic>? ?? {};
          final winnerId = result['winner'] as String? ?? '';
          final teamAId = tm['teamAId'] as String? ?? '';
          final teamBId = tm['teamBId'] as String? ?? '';

          if (winnerId.isNotEmpty) {
            teamRanks[winnerId] = 3;
            final loserId = winnerId == teamAId ? teamBId : teamAId;
            if (loserId.isNotEmpty) teamRanks[loserId] = 4;
          }
        }

        // 5位決定戦
        final fifthPlaceMatch = matches.docs.where((m) {
          final round = m.data()['round'] as String? ?? '';
          return round == 'final_5th';
        }).firstOrNull;

        if (fifthPlaceMatch != null) {
          final fm5 = fifthPlaceMatch.data();
          final result = fm5['result'] as Map<String, dynamic>? ?? {};
          final winnerId = result['winner'] as String? ?? '';
          final teamAId = fm5['teamAId'] as String? ?? '';
          final teamBId = fm5['teamBId'] as String? ?? '';

          if (winnerId.isNotEmpty) {
            teamRanks[winnerId] = 5;
            final loserId = winnerId == teamAId ? teamBId : teamAId;
            if (loserId.isNotEmpty) teamRanks[loserId] = 6;
          }
        }

        // 7位決定戦
        final seventhPlaceMatch = matches.docs.where((m) {
          final round = m.data()['round'] as String? ?? '';
          return round == 'final_7th';
        }).firstOrNull;

        if (seventhPlaceMatch != null) {
          final fm7 = seventhPlaceMatch.data();
          final result = fm7['result'] as Map<String, dynamic>? ?? {};
          final winnerId = result['winner'] as String? ?? '';
          final teamAId = fm7['teamAId'] as String? ?? '';
          final teamBId = fm7['teamBId'] as String? ?? '';

          if (winnerId.isNotEmpty) {
            teamRanks[winnerId] = 7;
            final loserId = winnerId == teamAId ? teamBId : teamAId;
            if (loserId.isNotEmpty) teamRanks[loserId] = 8;
          }
        }
      }
    }

    // ━━━ ポイント計算 & 付与 ━━━
    final batch = _firestore.batch();
    final pointHistoryData = <String, Map<String, dynamic>>{};

    // 現在のシーズン（年度）
    final now = DateTime.now();
    final season = now.month >= 4 ? now.year : now.year - 1;

    for (final entry in userTeamMap.entries) {
      final uid = entry.key;
      final teamId = entry.value;

      // 順位ポイント
      final rank = teamRanks[teamId] ?? 99;
      final rankPoints = calculateRankPoints(teamCount, rank);

      final totalEarned = rankPoints;

      // ユーザードキュメント更新
      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'totalPoints': FieldValue.increment(totalEarned),
        'seasonPoints': FieldValue.increment(totalEarned),
        'stats.tournamentsPlayed': FieldValue.increment(1),
        if (rank == 1) 'stats.championships': FieldValue.increment(1),
      });

      // ポイント履歴
      pointHistoryData[uid] = {
        'rankPoints': rankPoints,
        'streakBonus': 0,
        'totalEarned': totalEarned,
        'rank': rank <= 4 ? rank : null,
      };

      // ポイント履歴をユーザーのサブコレクションに保存
      final historyRef = userRef.collection('pointHistory').doc(tournamentId);
      batch.set(historyRef, {
        'tournamentId': tournamentId,
        'tournamentName': tournamentName,
        'date': tournament['date'] ?? '',
        'teamCount': teamCount,
        'rank': rank <= 4 ? rank : null,
        'rankPoints': rankPoints,
        'streakBonus': 0,
        'organizerBonus': 0,
        'totalEarned': totalEarned,
        'season': season,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ━━━ 主催者ボーナス ━━━
    if (organizerId.isNotEmpty) {
      final orgBonus = calculateOrganizerBonus(teamCount);
      final userRef = _firestore.collection('users').doc(organizerId);
      batch.update(userRef, {
        'totalPoints': FieldValue.increment(orgBonus),
        'seasonPoints': FieldValue.increment(orgBonus),
        'stats.tournamentsHosted': FieldValue.increment(1),
      });

      // 主催者が参加者でもある場合は履歴を更新、そうでなければ新規作成
      final historyRef = userRef.collection('pointHistory').doc(tournamentId);
      if (pointHistoryData.containsKey(organizerId)) {
        batch.update(historyRef, {
          'organizerBonus': orgBonus,
          'totalEarned': FieldValue.increment(orgBonus),
        });
      } else {
        batch.set(historyRef, {
          'tournamentId': tournamentId,
          'tournamentName': tournamentName,
          'date': tournament['date'] ?? '',
          'teamCount': teamCount,
          'rank': null,
          'rankPoints': 0,
          'streakBonus': 0,
          'organizerBonus': orgBonus,
          'totalEarned': orgBonus,
          'isOrganizer': true,
          'season': season,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // ━━━ ストリークボーナス（非同期で更新） ━━━
    // バッチ後に個別実行（各ユーザーの過去履歴を確認する必要があるため）
    batch.update(tournamentRef, {'pointsAwarded': true});

    await batch.commit();

    // ストリーク計算（バッチ外で実行）
    await _updateStreakBonuses(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      tournamentDate: tournament['date'] as String? ?? '',
      teamCount: teamCount,
      userIds: userTeamMap.keys.toList(),
      season: season,
    );

    // ポイント獲得通知を送信
    await _sendPointNotifications(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      userPointMap: pointHistoryData,
      teamCount: teamCount,
    );
  }

  /// ストリークボーナスの計算と付与
  /// 期間ベース: 前回参加から30日以内なら連続、30日空いたらリセット
  static const _streakWindowDays = 30;

  static Future<void> _updateStreakBonuses({
    required String tournamentId,
    required String tournamentName,
    required String tournamentDate,
    required int teamCount,
    required List<String> userIds,
    required int season,
  }) async {
    for (final uid in userIds) {
      try {
        // 今回含む直近の履歴を日付降順で取得
        final history = await _firestore
            .collection('users').doc(uid)
            .collection('pointHistory')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        // 連続参加カウント（期間ベース）
        int streak = 1; // 今回の参加で最低1
        final docs = history.docs;
        for (int i = 0; i < docs.length - 1; i++) {
          final current = docs[i].data()['createdAt'] as Timestamp?;
          final prev = docs[i + 1].data()['createdAt'] as Timestamp?;
          if (current == null || prev == null) break;
          final diffDays = current.toDate().difference(prev.toDate()).inDays;
          if (diffDays <= _streakWindowDays) {
            streak++;
          } else {
            break;
          }
        }

        // ストリークボーナス計算
        final streakBonus = calculateStreakBonus(streak);
        if (streakBonus > 0) {
          await _firestore.collection('users').doc(uid).update({
            'totalPoints': FieldValue.increment(streakBonus),
            'seasonPoints': FieldValue.increment(streakBonus),
            'streak': streak,
          });

          await _firestore
              .collection('users').doc(uid)
              .collection('pointHistory').doc(tournamentId)
              .update({
            'streakBonus': streakBonus,
            'totalEarned': FieldValue.increment(streakBonus),
          });
        } else {
          await _firestore.collection('users').doc(uid).update({
            'streak': streak,
          });
        }
      } catch (_) {
        // ストリーク更新失敗は致命的ではないので無視
      }
    }
  }

  /// ポイント獲得通知を全参加者に送信
  static Future<void> _sendPointNotifications({
    required String tournamentId,
    required String tournamentName,
    required Map<String, Map<String, dynamic>> userPointMap,
    required int teamCount,
  }) async {
    final batch = _firestore.batch();

    for (final entry in userPointMap.entries) {
      final uid = entry.key;
      final data = entry.value;
      final totalEarned = data['totalEarned'] as int;
      final rank = data['rank'] as int?;

      String detail = '';
      if (rank != null && rank <= 4) {
        final rankNames = {1: '優勝', 2: '準優勝', 3: '3位', 4: '4位'};
        detail = '（${rankNames[rank]}）';
      }

      final notifRef = _firestore
          .collection('users').doc(uid)
          .collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'points_earned',
        'senderId': 'system',
        'senderName': 'ポイント獲得',
        'message': '「$tournamentName」で +${totalEarned}pt 獲得！$detail',
        'tournamentId': tournamentId,
        'points': totalEarned,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// ポイントの仕組みボトムシートを表示（共通UI）
  static void showPointSystemInfo(BuildContext context) {
    final exampleTable = getPointTable(16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
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
              const Text('ポイントの仕組み',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 20),

              // 順位ポイント
              _infoSection(
                icon: Icons.emoji_events,
                color: Colors.amber,
                title: '順位ポイント',
                description: '参加チーム数 × 順位係数\nチーム数が多い大会ほど高ポイント！',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(children: const [
                        SizedBox(width: 60, child: Text('順位', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        SizedBox(width: 50, child: Text('係数', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(child: Text('16チーム例', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                      ]),
                      const Divider(),
                      _pointRow('優勝', '×3.0', '${exampleTable['優勝']}pt'),
                      _pointRow('準優勝', '×2.0', '${exampleTable['準優勝']}pt'),
                      _pointRow('3位', '×1.5', '${exampleTable['3位']}pt'),
                      _pointRow('4位', '×1.2', '${exampleTable['4位']}pt'),
                      _pointRow('参加', '×1.0', '${exampleTable['参加']}pt'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ストリークボーナス
              _infoSection(
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
                title: '連続参加ボーナス',
                description: '前回参加から30日以内に次の大会に参加するとストリーク継続！\n30日以上空くとリセットされます',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    _pointRow('2大会連続', '', '+5pt'),
                    _pointRow('3大会連続', '', '+10pt'),
                    _pointRow('4大会以上', '', '+15pt'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // 主催者ボーナス
              _infoSection(
                icon: Icons.volunteer_activism,
                color: AppTheme.success,
                title: '主催者ボーナス',
                description: '大会を開催するだけでポイント獲得！\n参加チーム数 × 0.3',
              ),
              const SizedBox(height: 16),

              // シーズン
              _infoSection(
                icon: Icons.calendar_today,
                color: AppTheme.info,
                title: 'シーズン制',
                description: '毎年4月にシーズンポイントがリセット\n通算ポイントは永久に蓄積されます',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _infoSection({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ]),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textSecondary)),
          if (child != null) ...[
            const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    );
  }

  static Widget _pointRow(String label, String multiplier, String points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13))),
        SizedBox(width: 50, child: Text(multiplier, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Expanded(child: Text(points, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }
}
