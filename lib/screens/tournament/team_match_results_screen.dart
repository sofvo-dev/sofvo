import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

class _LaurelWreathPainter extends CustomPainter {
  final Color color;
  final Color highlightColor;
  _LaurelWreathPainter(this.color, {Color? highlightColor})
      : highlightColor = highlightColor ?? Colors.white;

  Path _leafPath(double length, double width) {
    final half = length / 2;
    return Path()
      ..moveTo(0, -half)
      ..quadraticBezierTo(width / 2, -half * 0.15, 0, half)
      ..quadraticBezierTo(-width / 2, -half * 0.15, 0, -half)
      ..close();
  }

  Offset _posAt(Offset center, double radius, double rad, bool rightSide) {
    final sx = rightSide ? math.sin(rad) : -math.sin(rad);
    final sy = -math.cos(rad);
    return center + Offset(sx, sy) * radius;
  }

  void _drawBranch(Canvas canvas, Offset center, double radius, bool rightSide) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = highlightColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    const leafCount = 10;
    const startDeg = 16.0; // 王冠用に天頂を少し空ける
    const endDeg = 172.0; // 根本は下部中央で重ねる
    const eps = 0.01;
    for (int i = 0; i < leafCount; i++) {
      final t = i / (leafCount - 1);
      final deg = startDeg + (endDeg - startDeg) * t;
      final rad = deg * math.pi / 180;

      final pos = _posAt(center, radius, rad, rightSide);
      final posNext = _posAt(center, radius, rad + eps, rightSide);
      final dir = posNext - pos;
      final tangentAngle = math.atan2(dir.dy, dir.dx);

      // 葉先が外側・上方向にやや跳ねる束感を出す
      final fan = (rightSide ? 1 : -1) * 0.28;

      final leafLength = 9.0 + 11.0 * t;
      final leafWidth = leafLength * 0.46;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(tangentAngle - math.pi / 2 + fan);
      canvas.drawPath(_leafPath(leafLength, leafWidth), paint);
      canvas.save();
      canvas.translate(rightSide ? -leafWidth * 0.16 : leafWidth * 0.16, leafLength * 0.04);
      canvas.drawPath(_leafPath(leafLength * 0.74, leafWidth * 0.42), highlightPaint);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    _drawBranch(canvas, center, radius, false);
    _drawBranch(canvas, center, radius, true);
  }

  @override
  bool shouldRepaint(covariant _LaurelWreathPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TeamMatchResultsScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String teamId;
  final String teamName;
  final int? finalRank;

  const TeamMatchResultsScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.teamId,
    required this.teamName,
    this.finalRank,
  });

  @override
  State<TeamMatchResultsScreen> createState() => _TeamMatchResultsScreenState();
}

class _TeamMatchResultsScreenState extends State<TeamMatchResultsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription> _subs = [];

  // 予選試合: sectionLabel → matches
  final Map<String, List<Map<String, dynamic>>> _prelimMatches = {};
  // 決勝試合: bracketId → matches
  final Map<String, List<Map<String, dynamic>>> _finalMatchesByBracket = {};
  bool _loaded = false;

  // Stats
  int _wins = 0, _losses = 0, _setWins = 0, _setLosses = 0, _pointDiff = 0;

  static const _roundLabels = <String, String>{
    'semi': '準決勝',
    'final_1st': '決勝（1-2位）',
    'final_3rd': '3位決定戦',
    'final_5th': '5位決定戦',
    'final_7th': '7位決定戦',
    'final': '決勝',
    'round-robin': '総当たり',
  };

  static const _roundOrder = <String, int>{
    'round-robin': 0,
    'semi': 1,
    'final_7th': 2,
    'final_5th': 3,
    'final_3rd': 4,
    'final_1st': 5,
    'final': 5,
  };

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    // 予選ラウンド
    final roundsSub = _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('rounds')
        .snapshots()
        .listen((roundsSnap) {
      for (final roundDoc in roundsSnap.docs) {
        final roundNum = int.tryParse(roundDoc.id) ?? 0;
        final label = roundNum <= 1 ? '予選リーグ' : '予選$roundNumリーグ';

        final matchSub = roundDoc.reference
            .collection('matches')
            .snapshots()
            .listen((matchSnap) {
          if (!mounted) return;
          final myMatches = matchSnap.docs
              .where((d) {
                final data = d.data();
                return (data['teamAId'] == widget.teamId ||
                    data['teamBId'] == widget.teamId) &&
                    data['status'] == 'completed';
              })
              .map((d) => Map<String, dynamic>.from(d.data()))
              .toList();
          myMatches.sort((a, b) =>
              ((a['matchOrder'] as num?) ?? 0)
                  .compareTo((b['matchOrder'] as num?) ?? 0));
          setState(() {
            _prelimMatches[label] = myMatches;
            _loaded = true;
            _recalcStats();
          });
        });
        _subs.add(matchSub);
      }
      if (roundsSnap.docs.isEmpty) setState(() => _loaded = true);
    });
    _subs.add(roundsSub);

    // 決勝ブラケット
    final bracketsSub = _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('brackets')
        .snapshots()
        .listen((bracketsSnap) {
      for (final bracketDoc in bracketsSnap.docs) {
        final bracketId = bracketDoc.id;
        final matchSub = bracketDoc.reference
            .collection('matches')
            .snapshots()
            .listen((matchSnap) {
          if (!mounted) return;
          final myMatches = matchSnap.docs
              .where((d) {
                final data = d.data();
                return (data['teamAId'] == widget.teamId ||
                    data['teamBId'] == widget.teamId) &&
                    data['status'] == 'completed';
              })
              .map((d) => Map<String, dynamic>.from(d.data()))
              .toList();
          myMatches.sort((a, b) =>
              (_roundOrder[a['round'] as String? ?? ''] ?? 99)
                  .compareTo(_roundOrder[b['round'] as String? ?? ''] ?? 99));
          setState(() {
            _finalMatchesByBracket[bracketId] = myMatches;
            _loaded = true;
            _recalcStats();
          });
        });
        _subs.add(matchSub);
      }
      if (bracketsSnap.docs.isEmpty) setState(() => _loaded = true);
    });
    _subs.add(bracketsSub);
  }

  void _recalcStats() {
    int wins = 0, losses = 0, setWins = 0, setLosses = 0, diff = 0;
    final allMatches = [
      ..._prelimMatches.values.expand((l) => l),
      ..._finalMatchesByBracket.values.expand((l) => l),
    ];
    for (final m in allMatches) {
      final result = m['result'] as Map<String, dynamic>? ?? {};
      final isA = m['teamAId'] == widget.teamId;
      final mySets = isA
          ? (result['setsA'] as num?)?.toInt() ?? 0
          : (result['setsB'] as num?)?.toInt() ?? 0;
      final oppSets = isA
          ? (result['setsB'] as num?)?.toInt() ?? 0
          : (result['setsA'] as num?)?.toInt() ?? 0;
      final winner = result['winner'] as String? ?? '';
      if (winner == widget.teamId) {
        wins++;
      } else if (winner.isNotEmpty && winner != '引き分け') {
        losses++;
      }
      setWins += mySets;
      setLosses += oppSets;

      final sets = m['sets'] as List<dynamic>? ?? [];
      for (final s in sets) {
        final scoreA = (s['a'] as num?)?.toInt() ?? 0;
        final scoreB = (s['b'] as num?)?.toInt() ?? 0;
        diff += isA ? (scoreA - scoreB) : (scoreB - scoreA);
      }
    }
    _wins = wins;
    _losses = losses;
    _setWins = setWins;
    _setLosses = setLosses;
    _pointDiff = diff;
  }

  @override
  void dispose() {
    for (final sub in _subs) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPrelim = _prelimMatches.values.any((l) => l.isNotEmpty);
    final hasFinal = _finalMatchesByBracket.values.any((l) => l.isNotEmpty);
    final allFinalMatches = _finalMatchesByBracket.values
        .expand((l) => l)
        .toList()
      ..sort((a, b) =>
          (_roundOrder[a['round'] as String? ?? ''] ?? 99)
              .compareTo(_roundOrder[b['round'] as String? ?? ''] ?? 99));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          widget.teamName,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // チームヘッダー
                  _buildTeamHeader(),
                  const SizedBox(height: 12),
                  // 成績サマリー
                  _buildStatsSummary(),
                  const SizedBox(height: 20),
                  if (!hasPrelim && !hasFinal)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('まだ試合結果がありません',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ),
                  // 予選
                  if (hasPrelim) ...[
                    for (final entry in _prelimMatches.entries)
                      if (entry.value.isNotEmpty) ...[
                        _sectionLabel(entry.key),
                        const SizedBox(height: 8),
                        for (final match in entry.value) ...[
                          _buildMatchCard(match, isPrelim: true),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                      ],
                  ],
                  // 決勝
                  if (hasFinal) ...[
                    _sectionLabel('順位決定トーナメント'),
                    const SizedBox(height: 8),
                    for (final match in allFinalMatches) ...[
                      _buildMatchCard(match, isPrelim: false),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTeamHeader() {
    final rank = widget.finalRank;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        SizedBox(
          width: 64, height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (rank != null && rank <= 3)
                CustomPaint(
                  size: const Size(64, 64),
                  painter: _LaurelWreathPainter(
                    rank == 1
                        ? const Color(0xFFE0A526)
                        : rank == 2
                            ? const Color(0xFF9AA7AD)
                            : const Color(0xFFB97A3D),
                  ),
                )
              else
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              rank != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rank <= 3)
                          Icon(
                            Icons.emoji_events,
                            size: 18,
                            color: rank == 1
                                ? const Color(0xFFC8860A)
                                : rank == 2
                                    ? const Color(0xFF78858B)
                                    : const Color(0xFF9C5A24),
                          ),
                        Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: rank <= 3 ? 20 : 24,
                            fontWeight: FontWeight.w900, height: 1.1,
                            color: rank == 1
                                ? const Color(0xFFC8860A)
                                : rank == 2
                                    ? const Color(0xFF78858B)
                                    : rank == 3
                                        ? const Color(0xFF9C5A24)
                                        : AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '位',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, height: 1.1,
                            color: rank == 1
                                ? const Color(0xFFC8860A)
                                : rank == 2
                                    ? const Color(0xFF78858B)
                                    : rank == 3
                                        ? const Color(0xFF9C5A24)
                                        : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : const Icon(Icons.emoji_events_outlined, size: 24, color: AppTheme.textSecondary),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.teamName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(widget.tournamentName,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        _statCell('${_wins}勝${_losses}敗', '通算成績'),
        _divider(),
        _statCell('$_setWins-$_setLosses', 'セット勝敗'),
        _divider(),
        _statCell('${_pointDiff >= 0 ? '+' : ''}$_pointDiff', '得失点'),
      ]),
    );
  }

  Widget _statCell(String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary, letterSpacing: 0.04),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, {required bool isPrelim}) {
    final result = match['result'] as Map<String, dynamic>? ?? {};
    final isA = match['teamAId'] == widget.teamId;
    final myName = isA
        ? (match['teamAName'] as String? ?? widget.teamName)
        : (match['teamBName'] as String? ?? widget.teamName);
    final oppName = isA
        ? (match['teamBName'] as String? ?? '相手チーム')
        : (match['teamAName'] as String? ?? '相手チーム');
    final mySets = isA
        ? (result['setsA'] as num?)?.toInt() ?? 0
        : (result['setsB'] as num?)?.toInt() ?? 0;
    final oppSets = isA
        ? (result['setsB'] as num?)?.toInt() ?? 0
        : (result['setsA'] as num?)?.toInt() ?? 0;
    final winner = result['winner'] as String? ?? '';
    final isWin = winner == widget.teamId;
    final isDraw = winner == '引き分け';
    final resultLabel = isDraw ? '引き分け' : (isWin ? '勝利' : '敗北');
    final resultColor = isDraw
        ? Colors.grey
        : (isWin ? AppTheme.success : AppTheme.error);

    // Stage label
    String stageLabel;
    if (isPrelim) {
      final matchNum = (match['matchOrder'] as num?)?.toInt() ?? 0;
      stageLabel = '予選 ${matchNum}試合目';
    } else {
      final round = match['round'] as String? ?? '';
      stageLabel = _roundLabels[round] ?? round;
    }

    // Sets: top-level array on the match document
    final rawSets = match['sets'] as List<dynamic>? ?? [];
    final sets = rawSets.map((s) {
      final sa = (s['a'] as num?)?.toInt() ?? 0;
      final sb = (s['b'] as num?)?.toInt() ?? 0;
      return isA ? (sa, sb) : (sb, sa); // (myScore, oppScore)
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(stageLabel,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(resultLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: resultColor)),
              ),
            ]),
          ),
          // Table
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: _buildScoreTable(
              myName: myName,
              oppName: oppName,
              sets: sets,
              mySets: mySets,
              oppSets: oppSets,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTable({
    required String myName,
    required String oppName,
    required List<(int, int)> sets,
    required int mySets,
    required int oppSets,
  }) {
    final setCount = sets.length;

    // Header columns: チーム | S1 | S2 | [S3] | 合計
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FlexColumnWidth(3),
        for (int i = 0; i < setCount; i++) i + 1: const FixedColumnWidth(38),
        setCount + 1: const FixedColumnWidth(40),
      },
      children: [
        // Header row
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('チーム',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary)),
            ),
            for (int i = 0; i < setCount; i++)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('S${i + 1}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('合計',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
        // My team row
        TableRow(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                myName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final (myScore, oppScore) in sets)
              Center(
                child: Text(
                  '$myScore',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: myScore > oppScore
                        ? AppTheme.success
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            Center(
              child: Text(
                '$mySets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: mySets > oppSets
                      ? AppTheme.primaryColor
                      : AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        // Opponent row
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                oppName,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final (myScore, oppScore) in sets)
              Center(
                child: Text(
                  '$oppScore',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: oppScore > myScore
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            Center(
              child: Text(
                '$oppSets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: oppSets > mySets
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
