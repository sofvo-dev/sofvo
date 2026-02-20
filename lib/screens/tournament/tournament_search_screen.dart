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
  Set<String> _bookmarkedTournaments = {};
  Set<String> _bookmarkedRecruits = {};
  late TabController _tabController;

  // viewMode: 'tournament' | 'recruitment' | 'saved'
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
    _loadFollowing();
    _loadBookmarks();
  }

  Future<void> _loadFollowing() async {
    final user = _currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('following').get();
    if (mounted) { setState(() { _followingIds = snap.docs.map((d) => d.id).toSet(); }); }
  }

  Future<void> _loadBookmarks() async {
    final user = _currentUser;
    if (user == null) return;
    final tSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('bookmarks')
        .where('type', isEqualTo: 'tournament').get();
    final rSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('bookmarks')
        .where('type', isEqualTo: 'recruitment').get();
    if (mounted) {
      setState(() {
        _bookmarkedTournaments = tSnap.docs.map((d) => (d.data()['targetId'] ?? '') as String).toSet();
        _bookmarkedRecruits = rSnap.docs.map((d) => (d.data()['targetId'] ?? '') as String).toSet();
      });
    }
  }

  Future<void> _toggleTournamentBookmark(String docId, Map<String, dynamic> meta) async {
    final user = _currentUser;
    if (user == null) return;
    await BookmarkNotificationService.toggleBookmark(
        uid: user.uid, targetId: docId, type: 'tournament', metadata: meta);
    setState(() {
      if (_bookmarkedTournaments.contains(docId)) { _bookmarkedTournaments.remove(docId); }
      else { _bookmarkedTournaments.add(docId); }
    });
  }

  Future<void> _toggleRecruitBookmark(String targetId, Map<String, dynamic> meta) async {
    final user = _currentUser;
    if (user == null) return;
    await BookmarkNotificationService.toggleBookmark(
        uid: user.uid, targetId: targetId, type: 'recruitment', metadata: meta);
    setState(() {
      if (_bookmarkedRecruits.contains(targetId)) { _bookmarkedRecruits.remove(targetId); }
      else { _bookmarkedRecruits.add(targetId); }
    });
  }

  @override
  void dispose() { _tabController.dispose(); _searchController.dispose(); super.dispose(); }

  DateTime? _parseDate(String dateStr) {
    try {
      final p = dateStr.split('/');
      if (p.length >= 3) return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {}
    return null;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'メンズ': return Colors.blue[600]!;
      case 'レディース': return Colors.pink[400]!;
      case '混合': return Colors.green[600]!;
      default: return AppTheme.textSecondary;
    }
  }

  bool get _hasActiveFilter =>
      _filterType != 'すべて' || _filterArea != 'すべて' || _filterDateRange != null || _showPastTournaments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (_showFilter && _viewMode != 'saved') _buildFilterPanel(),
          Expanded(child: _buildContent()),
        ]),
      ),
    );
  }

  // ━━━ X風ヘッダー ━━━
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(children: [
            const SizedBox(width: 26),
            const Spacer(),
            const Text('さがす',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showFilter = !_showFilter),
              child: Icon(_showFilter ? Icons.tune : Icons.tune_outlined,
                  size: 24, color: _hasActiveFilter ? AppTheme.primaryColor : AppTheme.textPrimary),
            ),
          ]),
        ),
        // タブバー（X風アンダーライン）: フォロー中 | みんなの大会
        if (_viewMode != 'saved')
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.grey[200],
            tabs: const [
              Tab(text: 'フォロー中'),
              Tab(text: 'みんなの大会'),
            ],
          ),
        // モード切替（大会 | メンバー | 保存）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(children: [
            Expanded(child: _buildModeTab('大会', Icons.emoji_events_outlined, 'tournament')),
            const SizedBox(width: 8),
            Expanded(child: _buildModeTab('メンバー', Icons.people_outline, 'recruitment')),
            const SizedBox(width: 8),
            Expanded(child: _buildModeTab('保存', Icons.bookmark_outline, 'saved',
                activeColor: AppTheme.accentColor)),
          ]),
        ),
        // 検索バー
        if (_viewMode != 'saved')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _viewMode == 'tournament' ? '大会名・会場名で検索' : '名前・大会名で検索',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        if (_viewMode == 'saved') Container(height: 1, color: Colors.grey[200]),
      ]),
    );
  }

  Widget _buildModeTab(String label, IconData icon, String mode, {Color? activeColor}) {
    final isSelected = _viewMode == mode;
    final c = activeColor ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? c : Colors.grey[300]!),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: isSelected ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  // ━━━ フィルターパネル ━━━
  Widget _buildFilterPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip(Icons.sports_volleyball, _filterType == 'すべて' ? '種別' : _filterType,
                _filterType != 'すべて', color: _filterType != 'すべて' ? _typeColor(_filterType) : null,
                onTap: _showTypeFilter),
            const SizedBox(width: 8),
            _filterChip(Icons.location_on_outlined, _filterArea == 'すべて' ? 'エリア' : _filterArea,
                _filterArea != 'すべて', onTap: _showAreaFilter),
            const SizedBox(width: 8),
            _filterChip(Icons.calendar_month_outlined,
                _filterDateRange != null
                    ? '${_filterDateRange!.start.month}/${_filterDateRange!.start.day}〜${_filterDateRange!.end.month}/${_filterDateRange!.end.day}'
                    : '日付',
                _filterDateRange != null, onTap: _showDateFilter),
          ]),
        ),
        if (_viewMode == 'tournament') ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _showPastTournaments = !_showPastTournaments),
            child: Row(children: [
              SizedBox(width: 20, height: 20, child: Checkbox(
                value: _showPastTournaments,
                onChanged: (v) => setState(() => _showPastTournaments = v ?? false),
                activeColor: AppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
              const SizedBox(width: 8),
              const Text('終了した大会も表示', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ),
        ],
        if (_hasActiveFilter) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _filterType = 'すべて'; _filterArea = 'すべて';
              _filterDateRange = null; _showPastTournaments = false;
            }),
            child: Row(children: [
              Icon(Icons.refresh, size: 14, color: AppTheme.error),
              const SizedBox(width: 4),
              Text('フィルターをリセット', style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _filterChip(IconData icon, String label, bool isActive, {Color? color, required VoidCallback onTap}) {
    final c = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? c.withValues(alpha: 0.08) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? c : Colors.grey[300]!, width: isActive ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isActive ? c : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? c : AppTheme.textSecondary)),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down, size: 14, color: isActive ? c : AppTheme.textHint),
        ]),
      ),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('種別で絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...['すべて', '混合', 'メンズ', 'レディース'].map((t) {
            final isSelected = _filterType == t;
            final c = t == 'すべて' ? AppTheme.textSecondary : _typeColor(t);
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14,
                  backgroundColor: c.withValues(alpha: 0.12),
                  child: Icon(t == 'すべて' ? Icons.all_inclusive : Icons.circle, color: c, size: 14)),
              title: Text(t, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? c : AppTheme.textPrimary)),
              trailing: isSelected ? Icon(Icons.check_circle, color: c) : null,
              onTap: () { setState(() => _filterType = t); Navigator.pop(ctx); },
            );
          }),
        ]),
      ),
    );
  }

  void _showAreaFilter() {
    final areas = ['すべて', '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('エリアで絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(child: ListView(shrinkWrap: true, children: areas.map((a) => ListTile(
            dense: true,
            leading: Icon(a == 'すべて' ? Icons.public : Icons.location_on_outlined,
                color: _filterArea == a ? AppTheme.primaryColor : AppTheme.textSecondary, size: 20),
            title: Text(a, style: TextStyle(fontWeight: _filterArea == a ? FontWeight.bold : FontWeight.normal,
                color: _filterArea == a ? AppTheme.primaryColor : AppTheme.textPrimary)),
            trailing: _filterArea == a ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
            onTap: () { setState(() => _filterArea = a); Navigator.pop(ctx); },
          )).toList())),
        ]),
      ),
    );
  }

  void _showDateFilter() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _filterDateRange,
      locale: const Locale('ja'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.primaryColor, onPrimary: Colors.white, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() => _filterDateRange = range);
  }

  // ━━━ コンテンツ ━━━
  Widget _buildContent() {
    if (_viewMode == 'saved') return _buildSavedList();
    return TabBarView(
      controller: _tabController,
      children: [
        _viewMode == 'tournament' ? _buildTournamentList(true) : _buildRecruitList(true),
        _viewMode == 'tournament' ? _buildTournamentList(false) : _buildRecruitList(false),
      ],
    );
  }

  // ━━━ 保存済み ━━━
  Widget _buildSavedList() {
    final user = _currentUser;
    if (user == null) return const Center(child: Text('ログインしてください'));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid)
          .collection('bookmarks').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final allDocs = snap.data?.docs ?? [];
        final tDocs = allDocs.where((d) => (d.data() as Map)['type'] == 'tournament').toList();
        final rDocs = allDocs.where((d) => (d.data() as Map)['type'] == 'recruitment').toList();
        if (allDocs.isEmpty) return _emptyState(Icons.bookmark_outline, '保存した大会・募集はありません', 'ブックマークをタップして保存');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (tDocs.isNotEmpty) ...[
              _sectionHeader(Icons.emoji_events, '保存した大会', tDocs.length, AppTheme.primaryColor),
              const SizedBox(height: 8),
              ...tDocs.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildSavedTournamentCard(d))),
            ],
            if (rDocs.isNotEmpty) ...[
              if (tDocs.isNotEmpty) const SizedBox(height: 8),
              _sectionHeader(Icons.people, '保存したメンバー募集', rDocs.length, AppTheme.accentColor),
              const SizedBox(height: 8),
              ...rDocs.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildSavedRecruitCard(d))),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text('$title ($count件)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _emptyState(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 60, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
      if (sub.isNotEmpty) ...[const SizedBox(height: 6), Text(sub, style: const TextStyle(fontSize: 13, color: AppTheme.textHint))],
    ]));
  }

  Widget _buildSavedTournamentCard(DocumentSnapshot bmDoc) {
    final bm = bmDoc.data() as Map<String, dynamic>;
    final date = bm['date'] ?? '';
    final tournamentType = bm['tournamentType'] ?? '';
    final status = bm['status'] ?? '';
    final alerts = (bm['alerts'] as List?)?.cast<String>() ?? [];
    String day = '', month = '', weekday = '';
    try {
      final p = date.toString().split('/');
      if (p.length >= 3) {
        month = '${int.parse(p[1])}月'; day = p[2];
        final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        const w = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = w[d.weekday - 1];
      }
    } catch (_) {}
    final sc = status == '募集中' ? AppTheme.success : AppTheme.textSecondary;
    final tc = _typeColor(tournamentType);

    return GestureDetector(
      onTap: () {
        final tid = bm['targetId'] ?? '';
        if (tid.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => TournamentDetailScreen(tournament: {
                'id': tid, 'name': bm['title'] ?? '', 'date': date,
                'venue': bm['location'] ?? '', 'type': tournamentType, 'status': status,
              })));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: alerts.isNotEmpty ? AppTheme.warning.withValues(alpha: 0.4) : Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 日付ブロック
            _dateBlock(month, day, weekday, sc, tournamentType, tc),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bm['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 3),
                Flexible(child: Text(bm['location'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
              if (status.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
                ),
              ],
              if (alerts.contains('deadline')) _alertBadge(Icons.warning_amber, '締切が近い！', AppTheme.warning),
              if (alerts.contains('slots')) _alertBadge(Icons.group, '残り枠わずか！', AppTheme.error),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async { await bmDoc.reference.delete(); _loadBookmarks(); },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bookmark_remove, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('保存解除', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ]),
                ),
              ),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildSavedRecruitCard(DocumentSnapshot bmDoc) {
    final bm = bmDoc.data() as Map<String, dynamic>;
    final nickname = bm['nickname'] ?? '?';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
              child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                  style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nickname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if ((bm['tournamentName'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.emoji_events, size: 13, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Flexible(child: Text('${bm['tournamentName']} ${bm['tournamentDate'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ])),
          GestureDetector(
            onTap: () async { await bmDoc.reference.delete(); _loadBookmarks(); },
            child: Icon(Icons.bookmark_remove, size: 20, color: Colors.grey[400]),
          ),
        ]),
      ),
    );
  }

  // ━━━ 大会リスト ━━━
  Widget _buildTournamentList(bool friendsOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tournaments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final allDocs = snapshot.data?.docs ?? [];
        final query = _searchController.text.toLowerCase();
        final now = DateTime.now();

        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final oid = data['organizerId'] ?? '';
          final status = data['status'] ?? '準備中';
          final isF = _followingIds.contains(oid) || oid == _currentUser?.uid;
          if (status == '開催中' || status == '決勝中') return false;
          if (friendsOnly ? !isF : isF) return false;
          if (status == '終了' && !_showPastTournaments) return false;
          if (status == '準備中') return false;
          if (query.isNotEmpty) {
            final t = (data['title'] ?? '').toString().toLowerCase();
            final l = (data['location'] ?? '').toString().toLowerCase();
            if (!t.contains(query) && !l.contains(query)) return false;
          }
          if (_filterType != 'すべて' && (data['type'] ?? '') != _filterType) return false;
          if (_filterArea != 'すべて') {
            final l = (data['location'] ?? '').toString();
            if (!l.contains(_filterArea)) return false;
          }
          if (_filterDateRange != null) {
            final d = _parseDate(data['date'] ?? '');
            if (d == null || d.isBefore(_filterDateRange!.start) || d.isAfter(_filterDateRange!.end)) return false;
          }
          return true;
        }).toList();

        // 日付が近い順
        filtered.sort((a, b) {
          final da = _parseDate((a.data() as Map)['date'] ?? '') ?? DateTime(2099);
          final db = _parseDate((b.data() as Map)['date'] ?? '') ?? DateTime(2099);
          return da.difference(now).inDays.abs().compareTo(db.difference(now).inDays.abs());
        });

        if (filtered.isEmpty) {
          return _emptyState(
              friendsOnly ? Icons.emoji_events_outlined : Icons.explore_outlined,
              friendsOnly ? 'フォロー中の大会はありません' : '大会が見つかりません', '');
        }

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async { setState(() {}); await Future.delayed(const Duration(milliseconds: 500)); },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTournamentCard(filtered[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTournamentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '';
    final date = data['date'] ?? '';
    final location = data['location'] ?? '';
    final status = data['status'] ?? '準備中';
    final type = data['type'] ?? '';
    final currentTeams = data['currentTeams'] ?? 0;
    final maxTeams = data['maxTeams'] ?? 8;
    final organizerName = data['organizerName'] ?? '不明';
    final organizerId = data['organizerId'] ?? '';
    final deadline = data['deadline'] ?? '';
    final entryFee = data['entryFee'] ?? '';
    final isFollowing = _followingIds.contains(organizerId) || organizerId == _currentUser?.uid;
    final isSaved = _bookmarkedTournaments.contains(doc.id);
    final progress = maxTeams > 0 ? (currentTeams as num) / (maxTeams as num) : 0.0;

    Color sc;
    switch (status) {
      case '募集中': sc = AppTheme.success; break;
      case '満員': sc = AppTheme.error; break;
      default: sc = AppTheme.textSecondary;
    }
    String day = '', month = '', weekday = '';
    try {
      final p = date.split('/');
      if (p.length >= 3) {
        month = '${int.parse(p[1])}月'; day = p[2];
        final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        const w = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = w[d.weekday - 1];
      }
    } catch (_) {}
    final tc = _typeColor(type);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(tournament: {
          'id': doc.id, 'name': title, 'date': date, 'venue': location,
          'courts': 0, 'type': type, 'currentTeams': currentTeams,
          'maxTeams': maxTeams, 'fee': entryFee, 'status': status,
          'deadline': deadline, 'organizer': organizerName, 'isFollowing': isFollowing,
        }),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 日付ブロック
            _dateBlock(month, day, weekday, sc, type, tc),
            const SizedBox(width: 14),
            // コンテンツ
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // タイトル + ステータス
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc)),
                ),
              ]),
              const SizedBox(height: 6),
              // 主催者
              Row(children: [
                Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(organizerName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (!isFollowing) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                    child: Text('未フォロー', style: TextStyle(fontSize: 9, color: AppTheme.textHint)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              // 会場
              Row(children: [
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Flexible(child: Text(location,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis)),
              ]),
              // 締切・参加費
              if (deadline.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.timer_outlined, size: 13, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Text('締切 $deadline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                  if (entryFee.toString().isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.payments_outlined, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(entryFee.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ]),
              ] else if (entryFee.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.payments_outlined, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(entryFee.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
              ],
              const SizedBox(height: 10),
              // 参加チーム数バー + ブックマーク
              Row(children: [
                Text('$currentTeams/$maxTeams', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.toDouble().clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? AppTheme.error : progress >= 0.8 ? AppTheme.warning : AppTheme.success),
                    minHeight: 5,
                  ),
                )),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _toggleTournamentBookmark(doc.id, {
                    'title': title, 'date': date, 'location': location,
                    'tournamentType': type, 'status': status,
                  }),
                  child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 22, color: isSaved ? AppTheme.accentColor : Colors.grey[400]),
                ),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }

  // ━━━ 日付ブロック ━━━
  Widget _dateBlock(String month, String day, String weekday, Color sc, String type, Color tc) {
    return SizedBox(
      width: 52,
      child: Column(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(month, style: TextStyle(fontSize: 10, color: sc, fontWeight: FontWeight.w600)),
            Text(day, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: sc, height: 1.1)),
            if (weekday.isNotEmpty)
              Text('($weekday)', style: TextStyle(fontSize: 10, color: sc)),
          ]),
        ),
        if (type.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: tc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(type, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc)),
          ),
        ],
      ]),
    );
  }

  Widget _alertBadge(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ━━━ メンバー募集リスト ━━━
  Widget _buildRecruitList(bool friendsOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recruitments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final docs = snapshot.data?.docs ?? [];
        final query = _searchController.text.toLowerCase();
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (query.isNotEmpty) {
            final nn = (data['nickname'] ?? '').toString().toLowerCase();
            final tn = (data['tournamentName'] ?? '').toString().toLowerCase();
            if (!nn.contains(query) && !tn.contains(query)) return false;
          }
          if (_filterType != 'すべて' && (data['tournamentType'] ?? '') != _filterType) return false;
          if (_filterArea != 'すべて' && !(data['area'] ?? '').toString().contains(_filterArea)) return false;
          if (_filterDateRange != null) {
            final d = _parseDate(data['tournamentDate'] ?? '');
            if (d == null || d.isBefore(_filterDateRange!.start) || d.isAfter(_filterDateRange!.end)) return false;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) return _emptyState(Icons.person_search, 'メンバー募集が見つかりません', '');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRecruitCard(filtered[i]),
          ),
        );
      },
    );
  }

  Widget _buildRecruitCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nickname = data['nickname'] ?? '不明';
    final experience = data['experience'] ?? '';
    final tournamentName = data['tournamentName'] ?? '';
    final tournamentDate = data['tournamentDate'] ?? '';
    final recruitCount = data['recruitCount'] ?? 0;
    final comment = data['comment'] ?? '';
    final recruiterId = data['userId'] ?? '';
    final area = data['area'] ?? '';
    final tournamentType = data['tournamentType'] ?? '';
    final isFollowing = _followingIds.contains(recruiterId) || recruiterId == _currentUser?.uid;
    final isSaved = _bookmarkedRecruits.contains(recruiterId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(nickname,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                if (recruitCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('あと$recruitCount人', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error)),
                  ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (experience.isNotEmpty) _smallTag('競技歴 $experience', AppTheme.primaryColor),
                if (area.isNotEmpty) _smallTag(area, AppTheme.textSecondary),
                if (tournamentType.isNotEmpty) _smallTag(tournamentType, _typeColor(tournamentType)),
              ]),
            ])),
          ]),
          if (tournamentName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Row(children: [
                Icon(Icons.emoji_events, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tournamentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                  if (tournamentDate.isNotEmpty)
                    Text(tournamentDate, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ])),
              ]),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: isFollowing ? () {} : null,
              icon: Icon(isFollowing ? Icons.send : Icons.person_add, size: 15),
              label: Text(isFollowing ? '応募する' : 'フォローして応募',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? AppTheme.primaryColor : Colors.grey[300],
                foregroundColor: isFollowing ? Colors.white : AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _toggleRecruitBookmark(recruiterId, {
                'nickname': nickname, 'tournamentName': tournamentName, 'tournamentDate': tournamentDate,
              }),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isSaved ? AppTheme.accentColor.withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                    size: 22, color: isSaved ? AppTheme.accentColor : Colors.grey[400]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
