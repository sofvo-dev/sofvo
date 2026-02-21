import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../services/match_generator.dart';

class ScoreInputScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  final String roundId;
  final bool isBracket;
  final String? bracketId;

  const ScoreInputScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.roundId,
    this.isBracket = false,
    this.bracketId,
  });

  @override
  State<ScoreInputScreen> createState() => _ScoreInputScreenState();
}

class _ScoreInputScreenState extends State<ScoreInputScreen> {
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _match;
  Map<String, dynamic>? _rules;
  int _totalSets = 2;
  List<TextEditingController> _ctrlA = [];
  List<TextEditingController> _ctrlB = [];
  List<bool> _setConfirmed = [];
  bool _refereeConfirmed = false;
  bool _coachAConfirmed = false;
  bool _coachBConfirmed = false;
  bool _saving = false;
  bool _matchEnded = false;
  String _winner = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var c in _ctrlA) { c.dispose(); }
    for (var c in _ctrlB) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadData() async {
    final tournDoc = await _firestore.collection('tournaments').doc(widget.tournamentId).get();
    final rules = tournDoc.data()?['rules'] as Map<String, dynamic>? ?? {};

    DocumentSnapshot matchDoc;
    if (widget.isBracket) {
      matchDoc = await _firestore.collection('tournaments').doc(widget.tournamentId)
          .collection('brackets').doc(widget.bracketId)
          .collection('matches').doc(widget.matchId).get();
    } else {
      matchDoc = await _firestore.collection('tournaments').doc(widget.tournamentId)
          .collection('rounds').doc(widget.roundId)
          .collection('matches').doc(widget.matchId).get();
    }

    final matchData = matchDoc.data() as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final setCount = widget.isBracket ? (finalRules['sets'] ?? 3) : (preliminary['sets'] ?? 2);

    final existingSets = matchData['sets'] as List<dynamic>? ?? [];

    final ctrlA = <TextEditingController>[];
    final ctrlB = <TextEditingController>[];
    final confirmed = <bool>[];

    for (int i = 0; i < setCount; i++) {
      if (i < existingSets.length && existingSets[i] is Map) {
        ctrlA.add(TextEditingController(text: '${existingSets[i]['a'] ?? ''}'));
        ctrlB.add(TextEditingController(text: '${existingSets[i]['b'] ?? ''}'));
        confirmed.add(false); // re-validate on load
      } else {
        ctrlA.add(TextEditingController());
        ctrlB.add(TextEditingController());
        confirmed.add(false);
      }
    }

    setState(() {
      _match = matchData;
      _rules = rules;
      _totalSets = setCount;
      _ctrlA = ctrlA;
      _ctrlB = ctrlB;
      _setConfirmed = confirmed;
      _refereeConfirmed = matchData['refereeConfirmed'] ?? false;
      _coachAConfirmed = matchData['confirmedByA'] ?? false;
      _coachBConfirmed = matchData['confirmedByB'] ?? false;
    });

    _checkMatchEnd();
  }

  void _checkMatchEnd() {
    int setsA = 0, setsB = 0;
    int confirmedCount = 0;
    int totalA = 0, totalB = 0;
    for (int i = 0; i < _totalSets; i++) {
      if (!_setConfirmed[i]) continue;
      confirmedCount++;
      final a = int.tryParse(_ctrlA[i].text) ?? 0;
      final b = int.tryParse(_ctrlB[i].text) ?? 0;
      if (a > b) setsA++;
      else if (b > a) setsB++;
      totalA += a;
      totalB += b;
    }

    final neededToWin = _totalSets <= 2 ? _totalSets : (_totalSets / 2).ceil();
    setState(() {
      if (setsA >= neededToWin) {
        _matchEnded = true;
        _winner = 'a';
      } else if (setsB >= neededToWin) {
        _matchEnded = true;
        _winner = 'b';
      } else if (confirmedCount == _totalSets) {
        _matchEnded = true;
        _winner = setsA > setsB ? 'a' : (setsB > setsA ? 'b' : (totalA > totalB ? 'a' : (totalB > totalA ? 'b' : 'draw')));
      } else {
        _matchEnded = false;
        _winner = '';
      }
    });
  }


  Future<void> _autoSave() async {
    if (_match == null) return;
    final sets = <Map<String, dynamic>>[];
    for (int i = 0; i < _totalSets; i++) {
      sets.add({'a': int.tryParse(_ctrlA[i].text) ?? 0, 'b': int.tryParse(_ctrlB[i].text) ?? 0});
    }
    try {
      if (widget.isBracket) {
        await _firestore.collection('tournaments').doc(widget.tournamentId)
            .collection('brackets').doc(widget.bracketId).collection('matches').doc(widget.matchId)
            .update({'sets': sets});
      } else {
        await _firestore.collection('tournaments').doc(widget.tournamentId)
            .collection('rounds').doc(widget.roundId).collection('matches').doc(widget.matchId)
            .update({'sets': sets});
      }
    } catch (_) {}
  }

  Future<void> _saveResult() async {
    setState(() => _saving = true);

    int setsA = 0, setsB = 0, totalA = 0, totalB = 0;
    final setsData = <Map<String, int>>[];
    for (int i = 0; i < _totalSets; i++) {
      final a = int.tryParse(_ctrlA[i].text) ?? 0;
      final b = int.tryParse(_ctrlB[i].text) ?? 0;
      setsData.add({'a': a, 'b': b});
      totalA += a;
      totalB += b;
      if (a > b) setsA++;
      else if (b > a) setsB++;
    }

    final winnerId = setsA > setsB ? _match!['teamAId'] : (setsB > setsA ? _match!['teamBId'] : (totalA > totalB ? _match!['teamAId'] : (totalB > totalA ? _match!['teamBId'] : '引き分け')));
    final result = {
      'setsA': setsA, 'setsB': setsB,
      'totalPointsA': totalA, 'totalPointsB': totalB,
      'winner': winnerId,
    };

    try {
      final updateData = {
        'sets': setsData, 'result': result, 'status': 'completed',
        'refereeConfirmed': true, 'confirmedByA': _coachAConfirmed, 'confirmedByB': _coachBConfirmed,
      };

      if (widget.isBracket) {
        await _firestore.collection('tournaments').doc(widget.tournamentId)
            .collection('brackets').doc(widget.bracketId)
            .collection('matches').doc(widget.matchId).update(updateData);
        // Update bracket progression (semi -> final)
        await MatchGenerator().updateBracketProgression(
          tournamentId: widget.tournamentId, bracketId: widget.bracketId!);
      } else {
        await _firestore.collection('tournaments').doc(widget.tournamentId)
            .collection('rounds').doc(widget.roundId)
            .collection('matches').doc(widget.matchId).update(updateData);

        await MatchGenerator().updateStandings(
          tournamentId: widget.tournamentId,
          roundNumber: int.tryParse(widget.roundId.replaceAll('round_', '')) ?? 1,
          courtId: _match!['courtId'],
        );

        // 全試合完了チェック
        if (!widget.isBracket) {
          final roundNum = int.tryParse(widget.roundId.replaceAll('round_', '')) ?? 1;
          final allMatches = await _firestore.collection('tournaments').doc(widget.tournamentId)
              .collection('rounds').doc(widget.roundId).collection('matches').get();
          final allCompleted = allMatches.docs.every((d) => (d.data())['status'] == 'completed');
          if (allCompleted) {
            await _firestore.collection('tournaments').doc(widget.tournamentId)
                .update({'status': '予選${roundNum}完了'});
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('スコアを保存しました'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: AppTheme.error));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('スコア入力'), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text('${_match!['teamAName']} vs ${_match!['teamBName']}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A2E), foregroundColor: Colors.white, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // === 審判チーム ===
          if (_match!["refereeTeamName"] != null && (_match!["refereeTeamName"] as String).isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha:0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.sports, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Text("主審: ${_match!["refereeTeamName"] ?? "未定"} / 副審: ${_match!["subRefereeTeamName"] ?? "ー"}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
              ]),
            ),

          // === Team names header ===
          Row(children: [
            Expanded(child: Text(_match!['teamAName'] ?? '', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6CA6FF)))),
            const SizedBox(width: 40, child: Text('vs', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white38))),
            Expanded(child: Text(_match!['teamBName'] ?? '', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6C6C)))),
          ]),
          const SizedBox(height: 24),

          // === Set score inputs ===
          ...List.generate(_totalSets, (i) => _buildSetRow(i)),

          const SizedBox(height: 24),

          // === Match result summary ===
          if (_matchEnded) _buildResultSummary(),

          // === Confirmation sliders ===
          if (_matchEnded) ...[
            const SizedBox(height: 16),
            if (_winner == 'a')
              _buildConfirmSlider('${_match!['teamAName']} 監督確認（勝利チーム）', _coachAConfirmed, Icons.person,
                  () => setState(() { _coachAConfirmed = true; _coachBConfirmed = true; _refereeConfirmed = true; }))
            else if (_winner == 'b')
              _buildConfirmSlider('${_match!['teamBName']} 監督確認（勝利チーム）', _coachBConfirmed, Icons.person,
                  () => setState(() { _coachBConfirmed = true; _coachAConfirmed = true; _refereeConfirmed = true; }))
            else ...[
              // 引き分け: 両チームの監督が確認
              _buildConfirmSlider('${_match!['teamAName']} 監督確認', _coachAConfirmed, Icons.person,
                  () => setState(() { _coachAConfirmed = true; if (_coachBConfirmed) _refereeConfirmed = true; })),
              const SizedBox(height: 12),
              _buildConfirmSlider('${_match!['teamBName']} 監督確認', _coachBConfirmed, Icons.person,
                  () => setState(() { _coachBConfirmed = true; if (_coachAConfirmed) _refereeConfirmed = true; })),
            ],
          ],

          // === Save button ===
          if (_matchEnded && _refereeConfirmed && _coachAConfirmed && _coachBConfirmed) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveResult,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(_saving ? '保存中...' : '結果を確定する',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildSetRow(int setIndex) {
    final confirmed = _setConfirmed[setIndex];
    final prevConfirmed = setIndex == 0 || _setConfirmed[setIndex - 1];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confirmed ? Colors.white.withValues(alpha:0.08) : Colors.white.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: confirmed ? Colors.greenAccent.withValues(alpha:0.4) : Colors.white12),
      ),
      child: Column(children: [
        Row(children: [
          Text('第${setIndex + 1}セット', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: confirmed ? Colors.greenAccent : Colors.white70)),
          const Spacer(),
          if (confirmed)
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
              SizedBox(width: 4),
              Text('確認済み', style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
            ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _ctrlA[setIndex],
            enabled: !confirmed && prevConfirmed,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF6CA6FF)),
            decoration: InputDecoration(
              hintText: '0', hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.15), fontSize: 36),
              filled: true, fillColor: Colors.white.withValues(alpha:0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (_) { _checkMatchEnd(); _autoSave(); },
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(fontSize: 24, color: Colors.white38)),
          ),
          Expanded(child: TextField(
            controller: _ctrlB[setIndex],
            enabled: !confirmed && prevConfirmed,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFFF6C6C)),
            decoration: InputDecoration(
              hintText: '0', hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.15), fontSize: 36),
              filled: true, fillColor: Colors.white.withValues(alpha:0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (_) { _checkMatchEnd(); _autoSave(); },
          )),
        ]),
        if (!confirmed && prevConfirmed) ...[
          const SizedBox(height: 12),
          _buildConfirmSlider('スライドしてセット確認', false, Icons.check, () {
            final a = int.tryParse(_ctrlA[setIndex].text) ?? 0;
            final b = int.tryParse(_ctrlB[setIndex].text) ?? 0;
            if (a == 0 && b == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('スコアを入力してください'), backgroundColor: AppTheme.warning));
              return;
            }
            final preliminary = _rules?['preliminary'] as Map<String, dynamic>? ?? {};
            final finalRules = _rules?['final'] as Map<String, dynamic>? ?? {};
            final hasDeuce = widget.isBracket ? (finalRules['deuce'] ?? true) : (preliminary['deuce'] ?? false);
            final deuceCap = widget.isBracket ? (finalRules['deuceCap'] ?? 17) : (preliminary['deuceCap'] ?? 17);
            const target = 15;
            final high = a >= b ? a : b;
            final low = a >= b ? b : a;
            bool valid = false;
            if (!hasDeuce) {
              // No deuce: winner has exactly 15, loser has 0-14
              valid = (high == target && low < target);
            } else {
              // Deuce rules:
              // Normal win: winner=15, loser=0-13 (no deuce occurred)
              if (high == target && low <= 13) { valid = true; }
              // Deuce win by 2: both reached 14+, winner leads by exactly 2
              else if (high >= target && low >= 14 && high - low == 2) { valid = true; }
              // Cap win: winner=cap, loser=cap-1 (deuce must have occurred, so loser>=14)
              else if (high == deuceCap && low >= 14 && low == deuceCap - 1) { valid = true; }
            }
            if (!valid) {
              String msg;
              if (!hasDeuce) {
                msg = 'スコアが無効です（どちらかが15点で相手は14点以下）';
              } else {
                msg = 'スコアが無効です\n'
                    '• 通常: 15点で相手13点以下\n'
                    '• ジュース: 14-14以降2点差で決着\n'
                    '• キャップ: ${deuceCap}-${deuceCap - 1}で決着';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: AppTheme.error, duration: const Duration(seconds: 4)));
              return;
            }
            setState(() { _setConfirmed[setIndex] = true; });
            _checkMatchEnd();
          }),
        ],
      ]),
    );
  }

  Widget _buildResultSummary() {
    int setsA = 0, setsB = 0;
    for (int i = 0; i < _totalSets; i++) {
      final a = int.tryParse(_ctrlA[i].text) ?? 0;
      final b = int.tryParse(_ctrlB[i].text) ?? 0;
      if (a > b) setsA++;
      else if (b > a) setsB++;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha:0.3)),
      ),
      child: Column(children: [
        const Text('試合終了', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 8),
        Text('$setsA - $setsB',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(
          _winner == 'a' ? '${_match!['teamAName']} の勝利' :
          _winner == 'b' ? '${_match!['teamBName']} の勝利' : '引き分け',
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ]),
    );
  }

  Widget _buildConfirmSlider(String label, bool confirmed, IconData icon, VoidCallback onConfirm) {
    if (confirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.greenAccent.withValues(alpha:0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 8),
          Text('$label 完了', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async { onConfirm(); return false; },
      background: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.greenAccent, Colors.green]),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
        ]),
      ),
    );
  }
}
