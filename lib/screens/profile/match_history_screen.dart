import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 対戦ヒストリー画面
class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('対戦ヒストリー')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('対戦ヒストリー')),
      body: FutureBuilder<List<_MatchResult>>(
        future: _loadMatchHistory(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final matches = snapshot.data ?? [];
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('まだ対戦履歴がありません',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildMatchCard(matches[index]),
          );
        },
      ),
    );
  }

  Future<List<_MatchResult>> _loadMatchHistory(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final results = <_MatchResult>[];

    // ユーザーがエントリーした大会を探す
    final tournaments = await firestore
        .collection('tournaments')
        .orderBy('date', descending: true)
        .limit(50)
        .get();

    for (final tDoc in tournaments.docs) {
      final tData = tDoc.data();
      final tournamentName = (tData['title'] ?? tData['name'] ?? '大会') as String;
      final date = (tData['date'] ?? '') as String;

      // この大会でユーザーのエントリーを確認
      final entries = await firestore
          .collection('tournaments')
          .doc(tDoc.id)
          .collection('entries')
          .where('enteredBy', isEqualTo: uid)
          .get();

      if (entries.docs.isEmpty && tData['organizerId'] != uid) continue;

      // ユーザーのチームIDを取得
      final myTeamIds = entries.docs
          .map((e) => (e.data()['teamId'] ?? '') as String)
          .where((id) => id.isNotEmpty)
          .toSet();

      // 各ラウンドの試合を取得
      final roundsSnap = await firestore
          .collection('tournaments')
          .doc(tDoc.id)
          .collection('rounds')
          .get();

      for (final roundDoc in roundsSnap.docs) {
        final matchesSnap = await roundDoc.reference
            .collection('matches')
            .get();

        for (final matchDoc in matchesSnap.docs) {
          final m = matchDoc.data();
          final team1Id = (m['team1Id'] ?? '') as String;
          final team2Id = (m['team2Id'] ?? '') as String;

          if (myTeamIds.contains(team1Id) || myTeamIds.contains(team2Id)) {
            final isTeam1 = myTeamIds.contains(team1Id);
            final myScore = (isTeam1 ? m['score1'] : m['score2']) ?? 0;
            final oppScore = (isTeam1 ? m['score2'] : m['score1']) ?? 0;
            final myTeamName = (isTeam1 ? m['team1Name'] : m['team2Name']) ?? 'マイチーム';
            final oppTeamName = (isTeam1 ? m['team2Name'] : m['team1Name']) ?? '相手チーム';
            final court = (m['court'] ?? m['courtName'] ?? '') as String;

            String resultLabel = '未確定';
            Color resultColor = AppTheme.textSecondary;
            if (myScore is int && oppScore is int && (myScore > 0 || oppScore > 0)) {
              if (myScore > oppScore) {
                resultLabel = '勝ち';
                resultColor = AppTheme.success;
              } else if (myScore < oppScore) {
                resultLabel = '負け';
                resultColor = AppTheme.error;
              } else {
                resultLabel = '引分';
                resultColor = AppTheme.warning;
              }
            }

            results.add(_MatchResult(
              tournamentName: tournamentName,
              date: date,
              roundName: roundDoc.id.replaceAll('round_', 'R'),
              court: court,
              myTeamName: myTeamName as String,
              opponentName: oppTeamName as String,
              myScore: myScore is int ? myScore : 0,
              opponentScore: oppScore is int ? oppScore : 0,
              resultLabel: resultLabel,
              resultColor: resultColor,
            ));
          }
        }
      }
    }

    return results;
  }

  Widget _buildMatchCard(_MatchResult match) {
    return Container(
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
              Expanded(
                child: Text(match.tournamentName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(match.date, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          ),
          if (match.court.isNotEmpty || match.roundName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${match.roundName} ${match.court}',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(match.myTeamName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${match.myScore}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: match.resultColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(match.resultLabel,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: match.resultColor)),
                    ),
                    const SizedBox(height: 6),
                    Text('VS', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(match.opponentName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${match.opponentScore}',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchResult {
  final String tournamentName;
  final String date;
  final String roundName;
  final String court;
  final String myTeamName;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final String resultLabel;
  final Color resultColor;

  const _MatchResult({
    required this.tournamentName,
    required this.date,
    required this.roundName,
    required this.court,
    required this.myTeamName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.resultLabel,
    required this.resultColor,
  });
}
