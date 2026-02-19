import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../services/bookmark_notification_service.dart';
import 'tournament_detail_screen.dart';

class TournamentSearchScreen extends StatefulWidget {
  const TournamentSearchScreen({super.key});
  @override
  State<TournamentSearchScreen> createState() => _TournamentSearchScreenState();
}

class _TournamentSearchScreenState extends State<TournamentSearchScreen>
    with SingleTickerProviderStateMixin {
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  Set<String> _followingIds = {};
  Set<String> _enteredTournamentIds = {};
  Set<String> _bookmarkedTournaments = {};
  Set<String> _bookmarkedRecruits = {};
  late TabController _tabController;
  String _viewMode = 'tournament';

  bool _showFilter = false;
  String _filterType = 'すべて';
  String _filterArea = 'すべて';
  DateTimeRange? _filterDateRange;
  bool _showPastTournaments = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    _loadFollowing();
    _loadEnteredTournaments();
    _loadBookmarks();
  }

  Future<void> _loadFollowing() async {
    if (_currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(_currentUser!.uid)
        .collection('following').get();
    setState(() { _followingIds = snap.docs.map((d) => d.id).toSet(); });
  }

  Future<void> _loadEnteredTournaments() async {
    if (_currentUser == null) return;
    final snap = await FirebaseFirestore.instance.collection('tournaments').get();
    final entered = <String>{};
    for (final doc in snap.docs) {
      final entriesSnap = await doc.reference.collection('entries')
          .where('enteredBy', isEqualTo: _currentUser!.uid).limit(1).get();
      if (entriesSnap.docs.isNotEmpty) entered.add(doc.id);
    }
    if (mounted) setState(() { _enteredTournamentIds = entered; });
  }

  Future<void> _loadBookmarks() async {
    if (_currentUser == null) return;
    final tSnap = await FirebaseFirestore.instance
        .collection('users').doc(_currentUser!.uid).collection('bookmarks')
        .where('type', isEqualTo: 'tournament').get();
    final rSnap = await FirebaseFirestore.instance
        .collection('users').doc(_currentUser!.uid).collection('bookmarks')
        .where('type', isEqualTo: 'recruitment').get();
    if (mounted) setState(() {
      _bookmarkedTournaments = tSnap.docs.map((d) => (d.data()['targetId'] ?? '') as String).toSet();
      _bookmarkedRecruits = rSnap.docs.map((d) => (d.data()['targetId'] ?? '') as String).toSet();
    });
  }

  Future<void> _toggleTournamentBookmark(String docId, Map<String, dynamic> meta) async {
    if (_currentUser == null) return;
    await BookmarkNotificationService.toggleBookmark(
      uid: _currentUser!.uid, targetId: docId, type: 'tournament', metadata: meta);
    setState(() {
      if (_bookmarkedTournaments.contains(docId)) { _bookmarkedTournaments.remove(docId); }
      else { _bookmarkedTournaments.add(docId); }
    });
  }

  Future<void> _toggleRecruitBookmark(String targetId, Map<String, dynamic> meta) async {
    if (_currentUser == null) return;
    await BookmarkNotificationService.toggleBookmark(
      uid: _currentUser!.uid, targetId: targetId, type: 'recruitment', metadata: meta);
    setState(() {
      if (_bookmarkedRecruits.contains(targetId)) { _bookmarkedRecruits.remove(targetId); }
      else { _bookmarkedRecruits.add(targetId); }
    });
  }

  @override
  void dispose() { _tabController.dispose(); _searchController.dispose(); super.dispose(); }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {}
    return null;
  }

  Color _typeColor(String type) {
    switch (type) { case 'メンズ': return Colors.blue; case 'レディース': return Colors.pink; case '混合': return Colors.green; default: return AppTheme.textSecondary; }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _filterType != 'すべて' || _filterArea != 'すべて' || _filterDateRange != null || _showPastTournaments;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('さがす'),
        bottom: TabBar(
          controller: _tabController, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor, indicatorWeight: 3,
          tabs: const [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people, size: 18), SizedBox(width: 6), Text('フォロワーの大会')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.public, size: 18), SizedBox(width: 6), Text('みんなの大会')])),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── 固定ヘッダー ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // トグル
              SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _buildMiniToggle('大会をさがす', _viewMode == 'tournament', () => setState(() => _viewMode = 'tournament')),
                  const SizedBox(width: 8),
                  _buildMiniToggle('メンバーをさがす', _viewMode == 'recruitment', () => setState(() => _viewMode = 'recruitment')),
                  const SizedBox(width: 8),
                  _buildMiniToggle('保存済み', _viewMode == 'saved', () => setState(() => _viewMode = 'saved'),
                      icon: Icons.bookmark, activeColor: AppTheme.accentColor),
                ]),
              ),
              const SizedBox(height: 10),
              // 検索バー（保存済み以外）
              Row(children: [
                  Expanded(child: _viewMode == 'saved'
                    ? Container(height: 48)
                    : TextField(
                    controller: _searchController, style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _viewMode == 'tournament' ? '大会名・会場名で検索' : '名前・大会名で検索',
                      hintStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                      prefixIcon: const Icon(Icons.search, size: 22),
                      filled: true, fillColor: AppTheme.backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showFilter = !_showFilter),
                    child: Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasActiveFilter ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hasActiveFilter ? AppTheme.primaryColor : Colors.transparent)),
                      child: Stack(children: [
                        Icon(Icons.tune, size: 22, color: hasActiveFilter ? AppTheme.primaryColor : AppTheme.textSecondary),
                        if (hasActiveFilter) Positioned(right: -2, top: -2, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle))),
                      ]),
                    ),
                  ),
                ]),
              // フィルターパネル
              if (_showFilter && _viewMode != 'saved')
                Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                    _buildFilterChip(icon: Icons.sports_volleyball, label: _filterType == 'すべて' ? '種別' : _filterType, isActive: _filterType != 'すべて', color: _filterType != 'すべて' ? _typeColor(_filterType) : null, onTap: () => _showTypeFilter()),
                    const SizedBox(width: 8),
                    _buildFilterChip(icon: Icons.location_on, label: _filterArea == 'すべて' ? 'エリア' : _filterArea, isActive: _filterArea != 'すべて', onTap: () => _showAreaFilter()),
                    const SizedBox(width: 8),
                    _buildFilterChip(icon: Icons.calendar_today, label: _filterDateRange != null ? '${_filterDateRange!.start.month}/${_filterDateRange!.start.day}〜${_filterDateRange!.end.month}/${_filterDateRange!.end.day}' : '日付', isActive: _filterDateRange != null, onTap: () => _showDateFilter()),
                  ])),
                  if (_viewMode == 'tournament') ...[
                    const SizedBox(height: 10),
                    GestureDetector(onTap: () => setState(() => _showPastTournaments = !_showPastTournaments),
                      child: Row(children: [
                        SizedBox(width: 20, height: 20, child: Checkbox(value: _showPastTournaments, onChanged: (v) => setState(() => _showPastTournaments = v ?? false), activeColor: AppTheme.primaryColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                        const SizedBox(width: 8),
                        const Text('終了した大会も表示', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ])),
                  ],
                  if (hasActiveFilter) ...[
                    const SizedBox(height: 8),
                    GestureDetector(onTap: () => setState(() { _filterType = 'すべて'; _filterArea = 'すべて'; _filterDateRange = null; _showPastTournaments = false; }),
                      child: Row(children: [Icon(Icons.refresh, size: 14, color: AppTheme.error), const SizedBox(width: 4), Text('リセット', style: TextStyle(fontSize: 12, color: AppTheme.error))])),
                  ],
                ])),
              const SizedBox(height: 12),
            ]),
          ),
          // ── コンテンツ ──
          Expanded(
            child: TabBarView(controller: _tabController, children: [
              _viewMode == 'saved'
                  ? _buildSavedList()
                  : _viewMode == 'tournament'
                      ? _buildTournamentList(true)
                      : _buildRecruitList(true),
              _viewMode == 'saved'
                  ? _buildSavedList()
                  : _viewMode == 'tournament'
                      ? _buildTournamentList(false)
                      : _buildRecruitList(false),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required IconData icon, required String label, required bool isActive, Color? color, required VoidCallback onTap}) {
    final ac = color ?? AppTheme.primaryColor;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: isActive ? ac.withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? ac : Colors.grey[300]!, width: isActive ? 1.5 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: isActive ? ac : AppTheme.textSecondary), const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? ac : AppTheme.textSecondary)),
        const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, size: 16, color: isActive ? ac : AppTheme.textHint),
      ]),
    ));
  }

  void _showTypeFilter() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('種別で絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        ...['すべて', '混合', 'メンズ', 'レディース'].map((t) => ListTile(
          leading: t == 'すべて' ? const Icon(Icons.all_inclusive, color: AppTheme.textSecondary) : Icon(Icons.circle, color: _typeColor(t), size: 18),
          title: Text(t, style: TextStyle(fontWeight: _filterType == t ? FontWeight.bold : FontWeight.normal, color: _filterType == t ? _typeColor(t) : AppTheme.textPrimary)),
          trailing: _filterType == t ? Icon(Icons.check, color: _typeColor(t)) : null,
          onTap: () { setState(() => _filterType = t); Navigator.pop(ctx); },
        )),
      ])));
  }

  void _showAreaFilter() {
    final areas = ['すべて', '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄'];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('エリアで絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        Flexible(child: ListView(shrinkWrap: true, children: areas.map((a) => ListTile(
          leading: a == 'すべて' ? const Icon(Icons.public, color: AppTheme.textSecondary) : const Icon(Icons.location_on, color: AppTheme.primaryColor),
          title: Text(a, style: TextStyle(fontWeight: _filterArea == a ? FontWeight.bold : FontWeight.normal)),
          trailing: _filterArea == a ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
          onTap: () { setState(() => _filterArea = a); Navigator.pop(ctx); },
        )).toList())),
      ])));
  }

  void _showDateFilter() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(context: context, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _filterDateRange, locale: const Locale('ja'),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppTheme.primaryColor, onPrimary: Colors.white, surface: Colors.white)), child: child!));
    if (range != null) setState(() => _filterDateRange = range);
  }

  Widget _buildMiniToggle(String label, bool isSelected, VoidCallback onTap, {IconData? icon, Color? activeColor}) {
    final c = activeColor ?? AppTheme.primaryColor;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: isSelected ? c : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? c : Colors.grey[300]!)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.textSecondary), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppTheme.textSecondary)),
      ]),
    ));
  }

  // ━━━ 保存済み ━━━
  Widget _buildSavedList() {
    if (_currentUser == null) return const Center(child: Text('ログインしてください'));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('bookmarks').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        final allDocs = snap.data?.docs ?? [];
        final tDocs = allDocs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'tournament').toList();
        final rDocs = allDocs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'recruitment').toList();

        if (allDocs.isEmpty) return _emptyState(Icons.bookmark_border, '保存した大会・募集はありません', 'ブックマークをタップして保存');

        return ListView(padding: const EdgeInsets.all(16), children: [
          if (tDocs.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
              const Icon(Icons.emoji_events, size: 18, color: AppTheme.primaryColor), const SizedBox(width: 6),
              Text('保存した大会（${tDocs.length}件）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ])),
            ...tDocs.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildSavedTournamentCard(d))),
          ],
          if (rDocs.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(top: 8, bottom: 10), child: Row(children: [
              const Icon(Icons.people, size: 18, color: AppTheme.accentColor), const SizedBox(width: 6),
              Text('保存したメンバー募集（${rDocs.length}件）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ])),
            ...rDocs.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildSavedRecruitCard(d))),
          ],
        ]);
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey[300]), const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
      if (sub.isNotEmpty) ...[const SizedBox(height: 8), Text(sub, style: const TextStyle(fontSize: 13, color: AppTheme.textHint))],
    ]));
  }

  Widget _buildSavedTournamentCard(DocumentSnapshot bmDoc) {
    final bm = bmDoc.data() as Map<String, dynamic>;
    final alerts = (bm['alerts'] as List?)?.cast<String>() ?? [];
    final date = bm['date'] ?? ''; final type = bm['type'] ?? '';
    String day = '', month = '', weekday = '';
    try { final p = date.toString().split('/'); if (p.length >= 3) { month = '${int.parse(p[1])}月'; day = p[2]; final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); const w = ['月','火','水','木','金','土','日']; weekday = w[d.weekday-1]; } } catch (_) {}
    final sc = (bm['status']??'') == '募集中' ? AppTheme.success : AppTheme.textSecondary;
    final tc = _typeColor(type);
    return GestureDetector(
      onTap: () { final tid = bm['targetId']??''; if (tid.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {'id': tid, 'name': bm['title']??'', 'date': date, 'venue': bm['location']??'', 'type': type, 'status': bm['status']??''}))); },
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: alerts.isNotEmpty ? AppTheme.warning.withOpacity(0.5) : Colors.grey[200]!)),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: sc.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [Text(month, style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)), Text(day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: sc)), if (weekday.isNotEmpty) Text('($weekday)', style: TextStyle(fontSize: 10, color: sc))])),
            const SizedBox(height: 6),
            if (type.isNotEmpty) Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: tc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(type, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bm['title']??'', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Flexible(child: Text(bm['location']??'', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)))]),
            if (alerts.contains('deadline')) Padding(padding: const EdgeInsets.only(top: 6), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.warning_amber, size: 14, color: AppTheme.warning), const SizedBox(width: 4), Text('締切が近い！', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warning))]))),
            if (alerts.contains('slots')) Padding(padding: const EdgeInsets.only(top: 4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.group, size: 14, color: AppTheme.error), const SizedBox(width: 4), Text('残り枠わずか！', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error))]))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [GestureDetector(onTap: () async { await bmDoc.reference.delete(); _loadBookmarks(); },
              child: Row(children: [Icon(Icons.bookmark_remove, size: 16, color: AppTheme.textSecondary), const SizedBox(width: 4), Text('解除', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))]))]),
          ])),
        ]))),
    );
  }

  Widget _buildSavedRecruitCard(DocumentSnapshot bmDoc) {
    final bm = bmDoc.data() as Map<String, dynamic>;
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: AppTheme.accentColor.withOpacity(0.12), child: Text(((bm['nickname']??'?') as String).isNotEmpty ? (bm['nickname']??'?')[0] : '?', style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bm['nickname']??'', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          if ((bm['tournamentName']??'').toString().isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.emoji_events, size: 13, color: AppTheme.primaryColor), const SizedBox(width: 4), Flexible(child: Text('${bm['tournamentName']} ${bm['tournamentDate']??''}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)))])],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [GestureDetector(onTap: () async { await bmDoc.reference.delete(); _loadBookmarks(); },
            child: Row(children: [Icon(Icons.bookmark_remove, size: 16, color: AppTheme.textSecondary), const SizedBox(width: 4), Text('解除', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))]))]),
        ])),
      ])));
  }

  // ━━━ 大会リスト ━━━
  Widget _buildTournamentList(bool friendsOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        final allDocs = snapshot.data?.docs ?? [];
        final query = _searchController.text.toLowerCase();
        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final oid = data['organizerId']??''; final status = data['status']??'準備中';
          final isF = _followingIds.contains(oid) || oid == _currentUser?.uid;
          if (status == '開催中' || status == '決勝中') return false;
          if (friendsOnly) { if (!isF) return false; } else { if (isF) return false; }
          if (status == '終了' && !_showPastTournaments) return false;
          if (status == '準備中') return false;
          if (query.isNotEmpty) { final t = (data['title']??'').toString().toLowerCase(); final l = (data['location']??'').toString().toLowerCase(); final tp = (data['type']??'').toString().toLowerCase(); if (!t.contains(query) && !l.contains(query) && !tp.contains(query)) return false; }
          if (_filterType != 'すべて' && (data['type']??'') != _filterType) return false;
          if (_filterArea != 'すべて') { final l = (data['location']??'').toString(); final a = (data['area']??'').toString(); if (!l.contains(_filterArea) && !a.contains(_filterArea)) return false; }
          if (_filterDateRange != null) { final d = _parseDate(data['date']??''); if (d == null || d.isBefore(_filterDateRange!.start) || d.isAfter(_filterDateRange!.end)) return false; }
          return true;
        }).toList();
        filtered.sort((a, b) { final da = _parseDate((a.data() as Map)['date']??'') ?? DateTime(2099); final db = _parseDate((b.data() as Map)['date']??'') ?? DateTime(2099); return (da.difference(DateTime.now()).inDays).abs().compareTo((db.difference(DateTime.now()).inDays).abs()); });
        if (filtered.isEmpty) return _emptyState(friendsOnly ? Icons.emoji_events_outlined : Icons.explore_outlined, friendsOnly ? 'フォロー中の大会はありません' : '大会が見つかりません', '');
        return Column(children: [
          if (!friendsOnly) Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: [Icon(Icons.info_outline, size: 14, color: AppTheme.textHint), const SizedBox(width: 6), Expanded(child: Text('フォロー外の主催者の大会です', style: TextStyle(fontSize: 11, color: AppTheme.textHint)))])),
          Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildTournamentCard(filtered[i])))),
        ]);
      },
    );
  }

  Widget _buildTournamentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title']??''; final date = data['date']??''; final location = data['location']??'';
    final status = data['status']??'準備中'; final format = data['format']??''; final type = data['type']??'';
    final entryFee = data['entryFee']??''; final currentTeams = data['currentTeams']??0;
    final maxTeams = data['maxTeams']??8; final organizerName = data['organizerName']??'不明';
    final organizerId = data['organizerId']??''; final deadline = data['deadline']??'';
    final isFollowing = _followingIds.contains(organizerId) || organizerId == _currentUser?.uid;
    final isSaved = _bookmarkedTournaments.contains(doc.id);

    Color sc; switch (status) { case '募集中': sc = AppTheme.success; break; case '満員': sc = AppTheme.error; break; default: sc = AppTheme.textSecondary; }
    String day = '', month = '', weekday = '';
    try { final p = date.split('/'); if (p.length >= 3) { month = '${int.parse(p[1])}月'; day = p[2]; final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); const w = ['月','火','水','木','金','土','日']; weekday = w[d.weekday-1]; } } catch (_) {}
    final tc = _typeColor(type); final progress = maxTeams > 0 ? currentTeams / maxTeams : 0.0;
    String fd = format.toString().replaceAll('4人制', '').trim();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {'id': doc.id, 'name': title, 'date': date, 'venue': location, 'courts': 0, 'type': type, 'format': format, 'currentTeams': currentTeams, 'maxTeams': maxTeams, 'fee': entryFee, 'status': status, 'statusColor': sc, 'deadline': deadline, 'organizer': organizerName, 'isFollowing': isFollowing}))),
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: sc.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [Text(month, style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)), Text(day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: sc)), if (weekday.isNotEmpty) Text('($weekday)', style: TextStyle(fontSize: 10, color: sc))])),
            const SizedBox(height: 6),
            if (type.isNotEmpty) Container(width: 52, padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: tc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(type, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc)))]),
            const SizedBox(height: 6),
            Row(children: [Icon(Icons.person, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(organizerName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)), if (!isFollowing) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AppTheme.textHint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('未フォロー', style: TextStyle(fontSize: 9, color: AppTheme.textHint)))]]),
            const SizedBox(height: 4),
            Row(children: [Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Flexible(child: Text(location, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis))]),
            if (fd.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.sports_volleyball, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(fd, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))])],
            if (entryFee.toString().isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.payments, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(entryFee.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))])],
            if (deadline.toString().isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.timer_outlined, size: 13, color: AppTheme.warning), const SizedBox(width: 4), Text('締切: $deadline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning))])],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.groups, size: 14, color: AppTheme.textSecondary), const SizedBox(width: 4),
              Text('$currentTeams/$maxTeams', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? AppTheme.error : progress >= 0.8 ? AppTheme.warning : AppTheme.success), minHeight: 4))),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _toggleTournamentBookmark(doc.id, {'title': title, 'date': date, 'location': location, 'type': type, 'status': status}),
                child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 22, color: isSaved ? AppTheme.accentColor : Colors.grey[400]),
              ),
            ]),
          ])),
        ]))),
    );
  }

  // ━━━ メンバー募集リスト ━━━
  Widget _buildRecruitList(bool friendsOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recruitments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        final docs = snapshot.data?.docs ?? [];
        final query = _searchController.text.toLowerCase();
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // フィルター
          if (query.isNotEmpty) {
            final nn = (data['nickname']??'').toString().toLowerCase();
            final tn = (data['tournamentName']??'').toString().toLowerCase();
            final cm = (data['comment']??'').toString().toLowerCase();
            if (!nn.contains(query) && !tn.contains(query) && !cm.contains(query)) return false;
          }
          if (_filterType != 'すべて' && (data['tournamentType']??'') != _filterType) return false;
          if (_filterArea != 'すべて') {
            final area = (data['area']??'').toString();
            if (!area.contains(_filterArea)) return false;
          }
          if (_filterDateRange != null) {
            final d = _parseDate(data['tournamentDate']??'');
            if (d == null || d.isBefore(_filterDateRange!.start) || d.isAfter(_filterDateRange!.end)) return false;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) return _emptyState(Icons.person_search, 'メンバー募集が見つかりません', '');
        return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length,
          itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildRecruitCard(filtered[i])));
      },
    );
  }

  Widget _buildRecruitCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nickname = data['nickname']??'不明'; final experience = data['experience']??'';
    final tournamentName = data['tournamentName']??''; final tournamentDate = data['tournamentDate']??'';
    final recruitCount = data['recruitCount']??0; final comment = data['comment']??'';
    final recruiterId = data['userId']??''; final area = data['area']??'';
    final tournamentType = data['tournamentType']??'';
    final isFollowing = _followingIds.contains(recruiterId) || recruiterId == _currentUser?.uid;
    final isSaved = _bookmarkedRecruits.contains(recruiterId);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ヘッダー
        Row(children: [
          CircleAvatar(radius: 24, backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(nickname.isNotEmpty ? nickname[0] : '?', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              if (recruitCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('あと${recruitCount}人', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error))),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (experience.isNotEmpty) _buildSmallTag('競技歴 $experience', AppTheme.primaryColor),
              if (area.isNotEmpty) _buildSmallTag(area, AppTheme.textSecondary),
              if (tournamentType.isNotEmpty) _buildSmallTag(tournamentType, _typeColor(tournamentType)),
            ]),
          ])),
        ]),
        // 大会情報
        if (tournamentName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.emoji_events, size: 18, color: AppTheme.primaryColor), const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tournamentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                if (tournamentDate.isNotEmpty) Text(tournamentDate, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ])),
        ],
        // コメント
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(comment, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 12),
        // アクション
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: isFollowing ? () {} : null,
            icon: Icon(isFollowing ? Icons.send : Icons.person_add, size: 16),
            label: Text(isFollowing ? '応募する' : 'フォローして応募', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? AppTheme.primaryColor : Colors.grey[300],
              foregroundColor: isFollowing ? Colors.white : AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 10), minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _toggleRecruitBookmark(recruiterId, {'nickname': nickname, 'tournamentName': tournamentName, 'tournamentDate': tournamentDate}),
            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isSaved ? AppTheme.accentColor.withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 22, color: isSaved ? AppTheme.accentColor : Colors.grey[400])),
          ),
        ]),
      ])),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)));
  }
}
