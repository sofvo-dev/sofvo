import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';

class TournamentRulesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRules;
  final int? courtCount;
  final int? maxTeams;
  final String? startTime;
  final String? endTime;
  const TournamentRulesScreen({super.key, this.initialRules, this.courtCount, this.maxTeams, this.startTime, this.endTime});
  @override
  State<TournamentRulesScreen> createState() => _TournamentRulesScreenState();
}

class _TournamentRulesScreenState extends State<TournamentRulesScreen> {
  static const Color _prelimColor = Color(0xFF4CAF50);
  static const Color _finalColor = Color(0xFFE91E63);
  static const Color _otherColor = Color(0xFF607D8B);
  static const Color _suggestColor = Color(0xFF2196F3);

  // Court settings
  int _teamsPerCourt = 4;

  // Preliminary
  int _prelimRounds = 1;
  int _prelimSets = 2;
  bool _prelimDeuce = false;
  int _prelimDeuceCap = 17;

  // Scoring
  bool _useMatchPoints = true;
  int _scoreWin20 = 10;
  int _scoreWin11 = 7;
  int _scoreDraw = 4;
  int _scoreLose11 = 2;
  int _scoreLose02 = 0;

  // Final
  bool _hasFinal = true;
  int _finalSets = 3;
  bool _finalDeuce = true;
  int _finalDeuceCap = 17;
  bool _thirdPlace = true;
  bool _loserRevival = false;
  String _finalFormat = '順位別複数';
  int _finalTierCount = 3; // 2=上・中, 3=上・中・下

  // Other
  bool _uniformRequired = false;
  bool _snsVideoAllowed = true;
  String _lunchBreak = 'なし';

  // Section collapse
  bool _prelimOpen = true;
  bool _scoringOpen = true;
  bool _finalOpen = true;
  bool _otherOpen = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialRules != null) _loadRules(widget.initialRules!);
  }

  void _loadRules(Map<String, dynamic> r) {
    final p = r['preliminary'] as Map<String, dynamic>? ?? {};
    final f = r['final'] as Map<String, dynamic>? ?? {};
    final s = r['scoring'] as Map<String, dynamic>? ?? {};
    final o = r['other'] as Map<String, dynamic>? ?? {};
    final m = r['management'] as Map<String, dynamic>? ?? {};
    setState(() {
      _teamsPerCourt = m['teamsPerCourt'] ?? 4;
      _prelimRounds = p['rounds'] ?? 1;
      _prelimSets = p['sets'] ?? 2;
      _prelimDeuce = p['deuce'] ?? false;
      _prelimDeuceCap = p['deuceCap'] ?? 17;
      _useMatchPoints = s['enabled'] ?? true;
      _scoreWin20 = s['win20'] ?? 10;
      _scoreWin11 = s['win11'] ?? 7;
      _scoreDraw = s['draw'] ?? 4;
      _scoreLose11 = s['lose11'] ?? 2;
      _scoreLose02 = s['lose02'] ?? 0;
      _hasFinal = f['enabled'] ?? true;
      _finalSets = f['sets'] ?? 3;
      _finalDeuce = f['deuce'] ?? true;
      _finalDeuceCap = f['deuceCap'] ?? 17;
      _thirdPlace = f['thirdPlace'] ?? true;
      _loserRevival = f['loserRevival'] ?? false;
      _finalFormat = f['format'] ?? '順位別複数';
      _finalTierCount = f['tierCount'] ?? 3;
      _uniformRequired = o['uniformRequired'] ?? false;
      _snsVideoAllowed = o['snsVideoAllowed'] ?? true;
      _lunchBreak = o['lunchBreak'] ?? 'なし';
    });
  }

  Map<String, dynamic> _buildRules() {
    return {
      'management': {'teamsPerCourt': _teamsPerCourt},
      'preliminary': {
        'rounds': _prelimRounds, 'sets': _prelimSets, 'points': 15,
        'deuce': _prelimDeuce, 'deuceCap': _prelimDeuceCap,
      },
      'scoring': {
        'enabled': _useMatchPoints,
        'win20': _scoreWin20, 'win11': _scoreWin11, 'draw': _scoreDraw,
        'lose11': _scoreLose11, 'lose02': _scoreLose02,
      },
      'final': {
        'enabled': _hasFinal, 'sets': _finalSets, 'points': 15,
        'deuce': _finalDeuce, 'deuceCap': _finalDeuceCap,
        'thirdPlace': _thirdPlace, 'loserRevival': _loserRevival,
        'format': _finalFormat, 'tierCount': _finalTierCount,
      },
      'other': {
        'uniformRequired': _uniformRequired,
        'snsVideoAllowed': _snsVideoAllowed,
        'lunchBreak': _lunchBreak,
      },
    };
  }

  // ── Reset to defaults ──
  void _resetDefaults() {
    setState(() {
      _teamsPerCourt = 4;
      _prelimRounds = 1; _prelimSets = 2; _prelimDeuce = false; _prelimDeuceCap = 17;
      _useMatchPoints = true;
      _scoreWin20 = 10; _scoreWin11 = 7; _scoreDraw = 4; _scoreLose11 = 2; _scoreLose02 = 0;
      _hasFinal = true; _finalSets = 3; _finalDeuce = true; _finalDeuceCap = 17;
      _thirdPlace = true; _loserRevival = false; _finalFormat = '順位別複数';
      _uniformRequired = false; _snsVideoAllowed = true; _lunchBreak = 'なし';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('デフォルト設定に戻しました'), duration: Duration(seconds: 1)),
    );
  }

  // ── Kabirunrun Cup preset ──
  void _applyKabirunrunPreset() {
    setState(() {
      _teamsPerCourt = 4;
      _prelimRounds = 1; _prelimSets = 2; _prelimDeuce = false; _prelimDeuceCap = 17;
      _useMatchPoints = true;
      _scoreWin20 = 10; _scoreWin11 = 7; _scoreDraw = 4; _scoreLose11 = 2; _scoreLose02 = 0;
      _hasFinal = true; _finalSets = 3; _finalDeuce = true; _finalDeuceCap = 17;
      _thirdPlace = true; _loserRevival = false; _finalFormat = '順位別複数';
      _uniformRequired = true; _snsVideoAllowed = false; _lunchBreak = 'なし';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('かびるんるんかっぷ設定を適用しました'), duration: Duration(seconds: 1)),
    );
  }

  // ── Auto suggest ──
  Map<String, dynamic> _calcSuggestion() {
    final courts = widget.courtCount ?? 4;
    double hours = 8;
    if (widget.startTime != null && widget.endTime != null) {
      final s = _parseTime(widget.startTime!);
      final e = _parseTime(widget.endTime!);
      if (s != null && e != null) hours = e.difference(s).inMinutes / 60.0;
    }

    // チーム数: 管理画面から渡された値を優先、なければコート数×1コートチーム数
    final totalTeams = widget.maxTeams ?? (courts * _teamsPerCourt);
    // 実際の1コートあたりのチーム数を算出
    final actualTeamsPerCourt = (totalTeams / courts).ceil();

    // 1コート内の総当たり試合数 = n*(n-1)/2
    final matchesPerCourt = actualTeamsPerCourt * (actualTeamsPerCourt - 1) ~/ 2;

    // 1試合の所要時間（分）: 1セット10分 + コートチェンジ等
    // 1セットマッチ = 10分, 2セットマッチ(必ず2セット) = 20分, 2セット先取(2〜3セット) = 平均25分
    const matchOverhead = 3; // コートチェンジ・審判交代
    final prelimMatchMin = (_prelimSets == 1 ? 10 : (_prelimSets == 2 ? 20 : 25)) + matchOverhead;
    final totalPrelimTime = matchesPerCourt * prelimMatchMin * _prelimRounds;

    // 決勝トーナメントの試合数
    // 決勝の2セット先取はフルセットになりやすいので長めに見積もる
    final finalMatchMin = (_finalSets == 2 ? 20 : 30) + matchOverhead;
    int finalMatches = 0;
    if (_hasFinal) {
      if (_finalFormat == '順位別複数') {
        // 各区分4チームトーナメント想定: 準決2 + 決勝1 (+3位決定戦1)
        final matchesPerTier = _thirdPlace ? 4 : 3;
        finalMatches = matchesPerTier * _finalTierCount;
      } else {
        // 全チーム一本トーナメント: ラウンド数 = ceil(log2(totalTeams))
        final rounds = (totalTeams > 1) ? (totalTeams - 1).bitLength : 1;
        finalMatches = rounds + (_thirdPlace ? 1 : 0);
      }
    }
    // 決勝は複数コート並行可能
    final finalCourtCount = _hasFinal ? courts.clamp(1, finalMatches) : 1;
    final totalFinalTime = ((finalMatches / finalCourtCount).ceil()) * finalMatchMin;

    final lunchMin = _lunchBreak == 'なし' ? 0 : int.tryParse(_lunchBreak.replaceAll('分', '')) ?? 0;
    final overheadMin = 15; // 開閉会式・移行時間
    final totalMinutes = totalPrelimTime + totalFinalTime + lunchMin + overheadMin;
    final availableMinutes = (hours * 60).round();
    final fits = totalMinutes <= availableMinutes;

    return {
      'courts': courts,
      'totalTeams': totalTeams,
      'actualTeamsPerCourt': actualTeamsPerCourt,
      'matchesPerCourt': matchesPerCourt * _prelimRounds,
      'totalMatches': matchesPerCourt * _prelimRounds * courts,
      'prelimMinutes': totalPrelimTime,
      'finalMatches': finalMatches,
      'finalMinutes': totalFinalTime,
      'lunchMinutes': lunchMin,
      'overheadMinutes': overheadMin,
      'totalMinutes': totalMinutes,
      'availableMinutes': availableMinutes,
      'fits': fits,
      'hours': hours,
    };
  }

  DateTime? _parseTime(String t) {
    try {
      final parts = t.split(':');
      return DateTime(2025, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) { return null; }
  }

  Widget _buildSchedulePredictionCard(Map<String, dynamic> s, bool fits) {
    final courts = s['courts'] as int;
    final totalTeams = s['totalTeams'] as int;
    final teamsPerCourt = s['actualTeamsPerCourt'] as int;
    final matchesPerCourt = s['matchesPerCourt'] as int;
    final totalMatches = s['totalMatches'] as int;
    final prelimMin = s['prelimMinutes'] as int;
    final finalMatches = s['finalMatches'] as int;
    final finalMin = s['finalMinutes'] as int;
    final lunchMin = s['lunchMinutes'] as int;
    final overheadMin = s['overheadMinutes'] as int;
    final totalMin = s['totalMinutes'] as int;
    final availableMin = s['availableMinutes'] as int;
    final hours = (s['hours'] as double).toStringAsFixed(1);
    final progressRatio = availableMin > 0 ? (totalMin / availableMin).clamp(0.0, 1.5) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_suggestColor.withValues(alpha: 0.08), _suggestColor.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _suggestColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _suggestColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          ),
          child: Row(children: [
            Icon(Icons.auto_awesome, color: _suggestColor, size: 20),
            const SizedBox(width: 8),
            Text('スケジュール予測', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _suggestColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fits ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(fits ? '余裕あり' : '時間超過', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Team / Court summary row
          Row(children: [
            Expanded(child: _predictionTile(Icons.groups, '$totalTeams', 'チーム')),
            Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.2)),
            Expanded(child: _predictionTile(Icons.sports_volleyball, '$courts', 'コート')),
            Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.2)),
            Expanded(child: _predictionTile(Icons.grid_view, '${teamsPerCourt}チーム', '1コートあたり')),
          ]),
          const SizedBox(height: 14),

          // Time breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              _timeBreakdownRow('予選リーグ', '$matchesPerCourt試合/コート × $courts面', '${prelimMin}分'),
              if (_hasFinal) ...[
                const SizedBox(height: 6),
                _timeBreakdownRow('決勝', '$finalMatches試合', '${finalMin}分'),
              ],
              if (lunchMin > 0) ...[
                const SizedBox(height: 6),
                _timeBreakdownRow('昼休憩', '', '${lunchMin}分'),
              ],
              const SizedBox(height: 6),
              _timeBreakdownRow('開閉会式等', '', '${overheadMin}分'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
              Row(children: [
                const Text('合計', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${totalMin}分', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: fits ? const Color(0xFF4CAF50) : const Color(0xFFFF9800))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // Progress bar
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('利用可能: ${hours}h（${availableMin}分）', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const Spacer(),
              Text(
                fits ? '${availableMin - totalMin}分の余裕' : '${totalMin - availableMin}分オーバー',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fits ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressRatio.toDouble(),
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(fits ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)),
              ),
            ),
          ]),
          const SizedBox(height: 14),
        ])),
      ]),
    );
  }

  Widget _predictionTile(IconData icon, String value, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]);
  }

  Widget _timeBreakdownRow(String label, String detail, String time) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      if (detail.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(detail, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
      const Spacer(),
      Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── Template save/load ──
  Future<void> _saveTemplate() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('テンプレート名'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: '例: いつもの大会設定')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('保存')),
        ],
      );
    });
    if (name == null || name.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid)
        .collection('ruleTemplates').add({'name': name, 'rules': _buildRules(), 'createdAt': FieldValue.serverTimestamp()});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$name」を保存しました')));
  }

  Future<void> _loadTemplate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid)
        .collection('ruleTemplates').orderBy('createdAt', descending: true).get();
    if (!mounted) return;
    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存済みテンプレートがありません')));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('テンプレートを選択'),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(
          shrinkWrap: true, itemCount: snap.docs.length,
          itemBuilder: (_, i) {
            final doc = snap.docs[i];
            return ListTile(
              title: Text(doc['name'] ?? ''), subtitle: Text(_templateSummary(doc['rules'])),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () async {
                await doc.reference.delete();
                Navigator.pop(ctx);
                _loadTemplate();
              }),
              onTap: () => Navigator.pop(ctx, doc['rules'] as Map<String, dynamic>),
            );
          },
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル'))],
      );
    });
    if (selected != null) {
      _loadRules(selected);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('テンプレートを適用しました')));
    }
  }

  String _templateSummary(dynamic rules) {
    if (rules == null) return '';
    final r = rules as Map<String, dynamic>;
    final p = r['preliminary'] as Map<String, dynamic>? ?? {};
    final f = r['final'] as Map<String, dynamic>? ?? {};
    String setLabel(int sets) => sets == 1 ? '1セットマッチ' : (sets == 2 ? '2セットマッチ' : '2セット先取');
    return '予選: ${setLabel((p['sets'] ?? 2) as int)} / 決勝: ${f['enabled'] == true ? setLabel((f['sets'] ?? 3) as int) : 'なし'}';
  }

  @override
  Widget build(BuildContext context) {
    final calc = _calcSuggestion();
    final fits = calc['fits'] as bool;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ルール設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _buildRules())),
        actions: [
          IconButton(icon: const Icon(Icons.folder_open), tooltip: '過去の設定を読込', onPressed: _loadTemplate),
          IconButton(icon: const Icon(Icons.save), tooltip: 'この設定を保存', onPressed: _saveTemplate),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'reset') _resetDefaults();
              if (v == 'kabirunrun') _applyKabirunrunPreset();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reset', child: Text('デフォルトに戻す')),
              const PopupMenuItem(value: 'kabirunrun', child: Text('かびるんるんかっぷ設定')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Teams per court (only when maxTeams not provided) ──
          if (widget.maxTeams == null) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('1コートのチーム数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [3, 4, 5].map((n) {
                final sel = _teamsPerCourt == n;
                final matches = n == 3 ? 3 : (n == 4 ? 6 : 10);
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _teamsPerCourt = n),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primaryColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: sel ? null : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(children: [
                      Text('$nチーム', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('$matches試合', style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppTheme.textSecondary)),
                    ]),
                  ),
                ));
              }).toList()),
            ]),
          ),
          const SizedBox(height: 16),
          ],

          // ── Preliminary ──
          _collapsibleSection('予選ルール', Icons.sports_volleyball, _prelimColor, _prelimOpen, (v) => setState(() => _prelimOpen = v), [
            _choiceRow('予選ラウンド数', [1, 2], _prelimRounds, (v) => setState(() => _prelimRounds = v), _prelimColor),
            _setFormatSelector([1, 2, 3], _prelimSets, (v) => setState(() => _prelimSets = v), _prelimColor),
            _switchRow('ジュース（17点キャップ）', _prelimDeuce, (v) => setState(() { _prelimDeuce = v; if (v) _prelimDeuceCap = 17; }), _prelimColor),
          ]),
          const SizedBox(height: 12),

          // ── Scoring ──
          _collapsibleSection('勝ち点制', Icons.emoji_events, _prelimColor, _scoringOpen, (v) => setState(() => _scoringOpen = v), [
            _switchRow('勝ち点制を使用する', _useMatchPoints, (v) => setState(() => _useMatchPoints = v), _prelimColor),
            if (!_useMatchPoints)
              const Padding(padding: EdgeInsets.only(left: 8, top: 4),
                child: Text('※ 勝敗数のみで順位を決定します', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
            if (_useMatchPoints) ...[
              const SizedBox(height: 8),
              _pointRow('2-0 勝利', _scoreWin20, (v) => setState(() => _scoreWin20 = v)),
              _pointRow('1-1 得失点差勝ち', _scoreWin11, (v) => setState(() => _scoreWin11 = v)),
              _pointRow('1-1 同点（引分）', _scoreDraw, (v) => setState(() => _scoreDraw = v)),
              _pointRow('1-1 得失点差負け', _scoreLose11, (v) => setState(() => _scoreLose11 = v)),
              _pointRow('0-2 敗北', _scoreLose02, (v) => setState(() => _scoreLose02 = v)),
            ],
          ]),
          const SizedBox(height: 12),

          // ── Final ──
          _collapsibleSection('決勝トーナメント', Icons.account_tree, _finalColor, _finalOpen, (v) => setState(() => _finalOpen = v), [
            _switchRow('決勝トーナメントを行う', _hasFinal, (v) => setState(() => _hasFinal = v), _finalColor),
            if (_hasFinal) ...[
              const SizedBox(height: 8),
              const Padding(padding: EdgeInsets.only(bottom: 8),
                child: Text('トーナメント方式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              _formatCard('順位別複数', '順位帯ごとにトーナメント', Icons.view_column,
                _finalFormat == '順位別複数', () => setState(() => _finalFormat = '順位別複数'), _finalColor),
              if (_finalFormat == '順位別複数')
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                  child: _choiceRow('区分数', [2, 3], _finalTierCount, (v) => setState(() => _finalTierCount = v), _finalColor,
                    labels: {2: '上・中', 3: '上・中・下'}),
                ),
              const SizedBox(height: 8),
              _formatCard('全チーム一本', '全チームで1つの\nトーナメントを実施', Icons.account_tree,
                _finalFormat == '全チーム一本', () => setState(() => _finalFormat = '全チーム一本'), _finalColor),
              const SizedBox(height: 12),
              _setFormatSelector([2, 3], _finalSets, (v) => setState(() => _finalSets = v), _finalColor),
              _switchRow('ジュース（17点キャップ）', _finalDeuce, (v) => setState(() { _finalDeuce = v; if (v) _finalDeuceCap = 17; }), _finalColor),
              _switchRow('3位決定戦', _thirdPlace, (v) => setState(() => _thirdPlace = v), _finalColor),
              _switchRow('敗者復活戦', _loserRevival, (v) => setState(() => _loserRevival = v), _finalColor),
            ],
          ]),
          const SizedBox(height: 12),

          // ── Other ──
          _collapsibleSection('その他設定', Icons.settings, _otherColor, _otherOpen, (v) => setState(() => _otherOpen = v), [
            _switchRow('ユニフォーム番号必須', _uniformRequired, (v) => setState(() => _uniformRequired = v), _otherColor),
            _switchRow('SNS動画投稿許可', _snsVideoAllowed, (v) => setState(() => _snsVideoAllowed = v), _otherColor),
            _stringChoiceRow('昼休憩', ['なし', '30分', '45分', '60分'], _lunchBreak, (v) => setState(() => _lunchBreak = v)),
          ]),
          const SizedBox(height: 16),

          // ── Schedule Prediction Card ──
          _buildSchedulePredictionCard(calc, fits),
          const SizedBox(height: 24),

          // ── Save button ──
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _buildRules()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('この設定で保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Helper Widgets
  // ══════════════════════════════════════

  Widget _collapsibleSection(String title, IconData icon, Color color, bool isOpen, ValueChanged<bool> onToggle, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => onToggle(!isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.08),
              borderRadius: isOpen ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: color),
            ]),
          ),
        ),
        if (isOpen) Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }

  static const _setFormats = <int, Map<String, String>>{
    1: {'title': '1セットマッチ', 'sub': '1セットのみ'},
    2: {'title': '2セットマッチ', 'sub': '必ず2セット'},
    3: {'title': '2セット先取', 'sub': '最大3セット'},
  };

  Widget _setFormatSelector(List<int> options, int selected, ValueChanged<int> onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('セット数', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Row(children: options.map((o) {
          final sel = o == selected;
          final fmt = _setFormats[o]!;
          return Expanded(child: GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? color : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(fmt['title']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(fmt['sub']!, style: TextStyle(fontSize: 10, color: sel ? Colors.white70 : AppTheme.textSecondary)),
              ]),
            ),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _choiceRow(String label, List<int> options, int selected, ValueChanged<int> onChanged, Color color, {Map<int, String>? labels}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        Expanded(flex: 6, child: Wrap(spacing: 6, children: options.map((o) {
          final isSelected = o == selected;
          final displayText = labels?[o] ?? '$o';
          return GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(displayText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
            ),
          );
        }).toList())),
      ]),
    );
  }

  Widget _stringChoiceRow(String label, List<String> options, String selected, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        Expanded(flex: 6, child: Wrap(spacing: 6, children: options.map((o) {
          final isSelected = o == selected;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _otherColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(o, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
            ),
          );
        }).toList())),
      ]),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        Switch(value: value, onChanged: onChanged, activeColor: color),
      ]),
    );
  }

  Widget _pointRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 5, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () { if (value > 0) onChanged(value - 1); },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.remove, size: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$value pt', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: () { if (value < 20) onChanged(value + 1); },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _prelimColor.withValues(alpha:0.15), borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.add, size: 18, color: _prelimColor),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _formatCard(String title, String desc, IconData icon, bool selected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey[300]!, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 28, color: selected ? color : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: selected ? color : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 12, color: selected ? color.withValues(alpha:0.7) : AppTheme.textSecondary)),
          ])),
          if (selected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}
