import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// ポイント計算・付与サービス
class PointService {
  static final _firestore = FirebaseFirestore.instance;

  /// 順位ポイントを計算（Cloud Functions と同じ係数）
  /// 1位: チーム数 × 3.0, 2位: × 2.0, 3位: × 1.5, 4位: × 1.2, それ以外: チーム数 × 1.0
  static int calculateRankPoints(int teamCount, int rank) {
    switch (rank) {
      case 1: return (teamCount * 3.0).round();
      case 2: return (teamCount * 2.0).round();
      case 3: return (teamCount * 1.5).round();
      case 4: return (teamCount * 1.2).round();
      default: return (teamCount * 1.0).round();
    }
  }

  /// 大会のポイント表（UI表示用）を取得
  static Map<String, int> getPointTable(int teamCount) {
    return {
      '優勝': calculateRankPoints(teamCount, 1),
      '準優勝': calculateRankPoints(teamCount, 2),
      '3位': calculateRankPoints(teamCount, 3),
      '4位': calculateRankPoints(teamCount, 4),
      '参加': calculateRankPoints(teamCount, 99),
    };
  }

  /// ポイント計算の基準チーム数。
  /// 実際に参加しているチーム数（currentTeams / エントリー数）を優先し、
  /// 未確定の場合のみ募集枠（maxTeams）にフォールバックする。
  /// （募集枠基準だと、枠より多い/少ないチーム数で開催された場合に実態とずれるため）
  static int effectiveTeamCount({int? currentTeams, int? maxTeams}) {
    final current = currentTeams ?? 0;
    if (current > 0) return current;
    return maxTeams ?? 0;
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

    final tournamentName = tournament['title'] as String? ?? tournament['name'] as String? ?? '';

    // エントリーデータ取得
    final entries = await tournamentRef.collection('entries').get();

    // ポイントは実際に参加したチーム数（エントリー数）を基準に計算する。
    // エントリーが取れない場合のみ maxTeams / currentTeams にフォールバック。
    final entryTeamIds = <String>{};
    for (final doc in entries.docs) {
      final tid = (doc.data()['teamId'] as String?) ?? '';
      entryTeamIds.add(tid.isNotEmpty ? tid : doc.id);
    }
    final teamCount = entryTeamIds.isNotEmpty
        ? entryTeamIds.length
        : ((tournament['maxTeams'] as num?)?.toInt()
            ?? (tournament['currentTeams'] as num?)?.toInt() ?? 0);
    if (teamCount == 0) return;

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

    // ━━━ 順位情報取得（ブラケットから・全体順位） ━━━
    // 複数ブラケット（1部/2部/3部…のティア分け）の場合、各ブラケットの決勝勝者を
    // 一律1位にすると全ティアの勝者が優勝扱いになるため、ブラケットの rankRange
    // （例 "5〜8位"）の先頭数字を起点に全体順位へ変換する（サーバー側と同じロジック）
    final teamRanks = <String, int>{};

    final brackets = await tournamentRef.collection('brackets').get();
    for (final bDoc in brackets.docs) {
      final rankRange = (bDoc.data()['rankRange'] ?? '').toString();
      final rankMatch = RegExp(r'(\d+)').firstMatch(rankRange);
      final rankStart = rankMatch != null ? int.parse(rankMatch.group(1)!) : 1;

      final matches = await bDoc.reference.collection('matches')
          .where('status', isEqualTo: 'completed')
          .get();

      for (final mDoc in matches.docs) {
        final m = mDoc.data();
        final round = m['round'] as String? ?? '';
        final result = m['result'] as Map<String, dynamic>? ?? {};
        final winnerId = result['winner'] as String? ?? '';
        if (winnerId.isEmpty) continue;
        final teamAId = m['teamAId'] as String? ?? '';
        final teamBId = m['teamBId'] as String? ?? '';
        final loserId = winnerId == teamAId ? teamBId : teamAId;

        int? localRank; // ブラケット内順位（勝者側）
        if (round == 'final' || round == 'final_1st') localRank = 1;
        else if (round == 'third_place' || round == 'final_3rd') localRank = 3;
        else if (round == 'final_5th') localRank = 5;
        else if (round == 'final_7th') localRank = 7;
        if (localRank == null) continue;

        teamRanks[winnerId] = rankStart + localRank - 1;
        if (loserId.isNotEmpty) teamRanks[loserId] = rankStart + localRank;
      }
    }

    // ━━━ ポイント計算 & Cloud Function で付与 ━━━
    final pointHistoryData = <String, Map<String, dynamic>>{};
    final userPointsList = <Map<String, dynamic>>[];

    for (final entry in userTeamMap.entries) {
      final uid = entry.key;
      final teamId = entry.value;

      // 順位ポイント（1〜3位は係数、それ以外は1pt）
      final rank = teamRanks[teamId] ?? 99;
      final rankPoints = calculateRankPoints(teamCount, rank);

      userPointsList.add({
        'uid': uid,
        'rankPoints': rankPoints,
        'rank': rank,
      });

      // ポイント履歴（通知用）
      pointHistoryData[uid] = {
        'rankPoints': rankPoints,
        'totalEarned': rankPoints,
        'rank': rank <= 8 ? rank : null,
      };
    }

    // Cloud Function でサーバーサイドからポイント付与
    await FirebaseFunctions.instance.httpsCallable('distributePoints').call({
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'userPoints': userPointsList,
    });

    // pointsAwarded フラグを主催者権限で更新
    await tournamentRef.update({'pointsAwarded': true});

    // ポイント獲得通知を送信
    await _sendPointNotifications(
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      userPointMap: pointHistoryData,
      teamCount: teamCount,
    );
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
      if (rank != null && rank <= 3) {
        final rankNames = {1: '優勝', 2: '準優勝', 3: '3位'};
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
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(alignment: Alignment.centerRight, child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
              const Text('ポイントの仕組み',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 20),

              // 順位ポイント
              _infoSection(
                icon: Icons.emoji_events,
                color: Colors.amber,
                title: '順位ポイント',
                description: 'チーム数に応じたポイントが付与されます',
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
                        SizedBox(width: 80, child: Text('計算', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Expanded(child: Text('16チーム例', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right)),
                      ]),
                      const Divider(),
                      _pointRow('優勝', 'チーム数×3.0', '${exampleTable['優勝']}pt'),
                      _pointRow('準優勝', 'チーム数×2.0', '${exampleTable['準優勝']}pt'),
                      _pointRow('3位', 'チーム数×1.5', '${exampleTable['3位']}pt'),
                      _pointRow('4位', 'チーム数×1.2', '${exampleTable['4位']}pt'),
                      _pointRow('参加', 'チーム数×1.0', '${exampleTable['参加']}pt'),
                    ],
                  ),
                ),
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
