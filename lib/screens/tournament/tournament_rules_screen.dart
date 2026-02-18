import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';

class TournamentRulesScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRules;
  final int? courtCount;
  final String? startTime;
  final String? endTime;
  const TournamentRulesScreen({super.key, this.initialRules, this.courtCount, this.startTime, this.endTime});
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
        'format': _finalFormat,
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
    final totalTeams = courts * _teamsPerCourt;
    int matchesPerCourt;
    switch (_teamsPerCourt) {
      case 3: matchesPerCourt = 3; break;
      case 5: matchesPerCourt = 10; break;
      default: matchesPerCourt = 6;
    }
    final prelimMinutes = _prelimSets == 1 ? 12 : (_prelimSets == 2 ? 20 : 30);
    final totalPrelimTime = matchesPerCourt * prelimMinutes * _prelimRounds;
    final finalMinutes = _finalSets == 2 ? 20 : 35;
    final finalMatches = _hasFinal ? (_thirdPlace ? 3 : 2) : 0;
    final totalFinalTime = finalMatches * finalMinutes;
    final lunchMin = _lunchBreak == 'なし' ? 0 : int.tryParse(_lunchBreak.replaceAll('分', '')) ?? 0;
    final totalMinutes = totalPrelimTime + totalFinalTime + lunchMin + 30; // +30 for opening/closing
    final availableMinutes = (hours * 60).round();
    final fits = totalMinutes <= availableMinutes;

    return {
      'courts': courts,
      'totalTeams': totalTeams,
      'matchesPerCourt': matchesPerCourt * _prelimRounds,
      'prelimMinutes': totalPrelimTime,
      'finalMinutes': totalFinalTime,
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

  String _suggestRuleText() {
    final s = _calcSuggestion();
    final hours = (s['hours'] as double).toStringAsFixed(1);
    if (s['fits'] == true) {
      return '${s['courts']}コート × ${_teamsPerCourt}チーム = ${s['totalTeams']}チーム\n'
          '予選${s['matchesPerCourt']}試合/コート（約${s['prelimMinutes']}分）'
          '${_hasFinal ? ' + 決勝（約${s['finalMinutes']}分）' : ''}\n'
          '予想合計: 約${s['totalMinutes']}分 / 利用可能: ${hours}h（${s['availableMinutes']}分）\n'
          '✅ 時間内に収まります';
    } else {
      return '${s['courts']}コート × ${_teamsPerCourt}チーム = ${s['totalTeams']}チーム\n'
          '予選${s['matchesPerCourt']}試合/コート（約${s['prelimMinutes']}分）'
          '${_hasFinal ? ' + 決勝（約${s['finalMinutes']}分）' : ''}\n'
          '予想合計: 約${s['totalMinutes']}分 / 利用可能: ${hours}h（${s['availableMinutes']}分）\n'
          '⚠️ 時間超過の可能性あり → セット数を減らすか昼休憩を短縮';
    }
  }

  void _applyAutoSuggestion() {
    final s = _calcSuggestion();
    final available = s['availableMinutes'] as int;
    setState(() {
      if (available >= 480) {
        _prelimRounds = 2; _prelimSets = 2; _prelimDeuce = false;
        _hasFinal = true; _finalSets = 3; _finalDeuce = true;
      } else if (available >= 360) {
        _prelimRounds = 1; _prelimSets = 2; _prelimDeuce = false;
        _hasFinal = true; _finalSets = 3; _finalDeuce = true;
      } else if (available >= 240) {
        _prelimRounds = 1; _prelimSets = 2; _prelimDeuce = false;
        _hasFinal = true; _finalSets = 2; _finalDeuce = false;
      } else {
        _prelimRounds = 1; _prelimSets = 1; _prelimDeuce = false;
        _hasFinal = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('おすすめルールを適用しました'), duration: Duration(seconds: 1)),
    );
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
    return '予選${p['sets'] ?? 2}セット / 決勝${f['enabled'] == true ? '${f['sets'] ?? 3}セット' : 'なし'}';
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestRuleText();
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

          // ── Auto Suggest Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_suggestColor.withOpacity(0.1), _suggestColor.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _suggestColor.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome, color: _suggestColor, size: 20),
                const SizedBox(width: 8),
                Text('スケジュール予測', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _suggestColor)),
              ]),
              const SizedBox(height: 10),
              Text(suggestion, style: TextStyle(fontSize: 13, color: fits ? AppTheme.textPrimary : Colors.orange[800], height: 1.5)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _applyAutoSuggestion,
                icon: Icon(Icons.auto_fix_high, size: 18, color: _suggestColor),
                label: Text('おすすめルールを適用', style: TextStyle(color: _suggestColor, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: _suggestColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Teams per court ──
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
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

          // ── Preliminary ──
          _collapsibleSection('予選ルール', Icons.sports_volleyball, _prelimColor, _prelimOpen, (v) => setState(() => _prelimOpen = v), [
            _choiceRow('予選ラウンド数', [1, 2], _prelimRounds, (v) => setState(() => _prelimRounds = v), _prelimColor),
            _choiceRow('セット数', [1, 2, 3], _prelimSets, (v) => setState(() => _prelimSets = v), _prelimColor),
            _switchRow('ジュース（デュース）', _prelimDeuce, (v) => setState(() => _prelimDeuce = v), _prelimColor),
            if (_prelimDeuce)
              _choiceRow('ジュース上限', [17, 21, 25], _prelimDeuceCap, (v) => setState(() => _prelimDeuceCap = v), _prelimColor),
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
              _formatCard('順位別複数', '上位・中位・下位など\n順位帯ごとにトーナメント', Icons.view_column,
                _finalFormat == '順位別複数', () => setState(() => _finalFormat = '順位別複数'), _finalColor),
              const SizedBox(height: 8),
              _formatCard('全チーム一本', '全チームで1つの\nトーナメントを実施', Icons.account_tree,
                _finalFormat == '全チーム一本', () => setState(() => _finalFormat = '全チーム一本'), _finalColor),
              const SizedBox(height: 12),
              _choiceRow('セット数', [2, 3], _finalSets, (v) => setState(() => _finalSets = v), _finalColor),
              _switchRow('ジュース', _finalDeuce, (v) => setState(() => _finalDeuce = v), _finalColor),
              if (_finalDeuce)
                _choiceRow('ジュース上限', [17, 21, 25], _finalDeuceCap, (v) => setState(() => _finalDeuceCap = v), _finalColor),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => onToggle(!isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
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

  Widget _choiceRow(String label, List<int> options, int selected, ValueChanged<int> onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
        Expanded(flex: 6, child: Wrap(spacing: 6, children: options.map((o) {
          final isSelected = o == selected;
          return GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$o', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
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
              decoration: BoxDecoration(color: _prelimColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
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
          color: selected ? color.withOpacity(0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey[300]!, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 28, color: selected ? color : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: selected ? color : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 12, color: selected ? color.withOpacity(0.7) : AppTheme.textSecondary)),
          ])),
          if (selected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}
