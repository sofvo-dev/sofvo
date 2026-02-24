import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// MVP投票画面
/// 大会終了後、参加者が他の参加者（自チーム以外）に投票できる
class MvpVotingScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const MvpVotingScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<MvpVotingScreen> createState() => _MvpVotingScreenState();
}

class _MvpVotingScreenState extends State<MvpVotingScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _myVoteTeamId;
  bool _hasVoted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkMyVote();
  }

  Future<void> _checkMyVote() async {
    final voteSnap = await _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('mvpVotes').doc(_uid).get();
    if (voteSnap.exists) {
      setState(() {
        _hasVoted = true;
        _myVoteTeamId = voteSnap.data()?['teamId'] as String?;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _vote(String teamId, String teamName) async {
    if (_hasVoted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('MVP投票', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('「$teamName」にMVP投票しますか？\n投票は1回のみ変更できません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('投票する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('mvpVotes').doc(_uid).set({
      'teamId': teamId,
      'teamName': teamName,
      'voterId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // チームのmvpVoteCountをインクリメント
    final entrySnap = await _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('entries').where('teamId', isEqualTo: teamId).limit(1).get();
    if (entrySnap.docs.isNotEmpty) {
      await entrySnap.docs.first.reference.update({
        'mvpVoteCount': FieldValue.increment(1),
      });
    }

    setState(() {
      _hasVoted = true;
      _myVoteTeamId = teamId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.how_to_vote, color: Colors.white),
            const SizedBox(width: 8),
            Text('$teamName に投票しました！'),
          ]),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('MVP投票', style: TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                // ヘッダー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                    ),
                  ),
                  child: Column(children: [
                    const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
                    const SizedBox(height: 8),
                    Text(widget.tournamentName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(_hasVoted ? '投票済みです' : '最も活躍したチームに投票しよう！',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
                // 投票結果（投票済みの場合）
                if (_hasVoted) _buildResults(),
                // チーム一覧
                if (!_hasVoted) _buildTeamList(),
              ],
            ),
    );
  }

  Widget _buildTeamList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tournaments').doc(widget.tournamentId)
            .collection('entries').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          final entries = snap.data!.docs;
          if (entries.isEmpty) return const Center(child: Text('エントリーチームがありません'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final data = entries[i].data() as Map<String, dynamic>;
              final teamId = data['teamId'] as String? ?? '';
              final teamName = data['teamName'] as String? ?? '不明';
              // 自チームには投票不可
              final isMyTeam = data['enteredBy'] == _uid;

              return GestureDetector(
                onTap: isMyTeam ? null : () => _vote(teamId, teamName),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMyTeam ? Colors.grey[200]! : AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isMyTeam ? Colors.grey[100] : AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Icon(Icons.groups, size: 22, color: isMyTeam ? AppTheme.textHint : AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(teamName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                          color: isMyTeam ? AppTheme.textHint : AppTheme.textPrimary)),
                      if (isMyTeam) Text('自チーム（投票不可）', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ])),
                    if (!isMyTeam)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('投票', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tournaments').doc(widget.tournamentId)
            .collection('entries').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          final entries = snap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
          entries.sort((a, b) => ((b['mvpVoteCount'] ?? 0) as int).compareTo((a['mvpVoteCount'] ?? 0) as int));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final data = entries[i];
              final teamId = data['teamId'] as String? ?? '';
              final teamName = data['teamName'] as String? ?? '不明';
              final voteCount = (data['mvpVoteCount'] ?? 0) as int;
              final isMyVote = teamId == _myVoteTeamId;
              final rank = i + 1;

              Color? rankColor;
              IconData? rankIcon;
              if (rank == 1 && voteCount > 0) { rankColor = Colors.amber; rankIcon = Icons.emoji_events; }
              else if (rank == 2 && voteCount > 0) { rankColor = Colors.grey[400]; rankIcon = Icons.star; }
              else if (rank == 3 && voteCount > 0) { rankColor = Colors.brown[300]; rankIcon = Icons.star_half; }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isMyVote ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMyVote ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.grey[200]!),
                ),
                child: Row(children: [
                  if (rankIcon != null)
                    Icon(rankIcon, size: 28, color: rankColor)
                  else
                    SizedBox(width: 28, child: Text('$rank', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(teamName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (isMyVote) Text('あなたの投票先', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: voteCount > 0 ? AppTheme.accentColor.withValues(alpha: 0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('$voteCount票', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: voteCount > 0 ? AppTheme.accentColor : AppTheme.textHint)),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
