import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
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
  late TabController _tabController;
  bool _showTournaments = true;

  // フィルター
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

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {}
    return null;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'メンズ': return Colors.blue;
      case 'レディース': return Colors.pink;
      case '混合': return Colors.green;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriends = _tabController.index == 0;
    final hasActiveFilter = _filterType != 'すべて' || _filterArea != 'すべて' || _filterDateRange != null || _showPastTournaments;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('さがす'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.people, size: 18), SizedBox(width: 6), Text('友達の大会'),
            ])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.public, size: 18), SizedBox(width: 6), Text('みんなの大会'),
            ])),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      _buildMiniToggle('大会をさがす', _showTournaments, () => setState(() => _showTournaments = true)),
                      const SizedBox(width: 8),
                      _buildMiniToggle('メンバーをさがす', !_showTournaments, () => setState(() => _showTournaments = false)),
                    ]),
                  ),
                // 検索バー + フィルターアイコン
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: (_showTournaments || !isFriends) ? '大会名・会場名で検索' : 'メンバー募集を検索',
                        hintStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                        prefixIcon: const Icon(Icons.search, size: 22),
                        filled: true,
                        fillColor: AppTheme.backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_showTournaments || !isFriends) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showFilter = !_showFilter),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasActiveFilter ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: hasActiveFilter ? AppTheme.primaryColor : Colors.transparent),
                        ),
                        child: Stack(children: [
                          Icon(Icons.tune, size: 22, color: hasActiveFilter ? AppTheme.primaryColor : AppTheme.textSecondary),
                          if (hasActiveFilter)
                            Positioned(right: -2, top: -2,
                              child: Container(width: 8, height: 8,
                                decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle)),
                            ),
                        ]),
                      ),
                    ),
                  ],
                ]),
                // フィルターパネル（展開時のみ）
                if (_showFilter && (_showTournaments || !isFriends))
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _buildFilterChip(
                            icon: Icons.sports_volleyball,
                            label: _filterType == 'すべて' ? '種別' : _filterType,
                            isActive: _filterType != 'すべて',
                            color: _filterType != 'すべて' ? _typeColor(_filterType) : null,
                            onTap: () => _showTypeFilter(),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            icon: Icons.location_on,
                            label: _filterArea == 'すべて' ? 'エリア' : _filterArea,
                            isActive: _filterArea != 'すべて',
                            onTap: () => _showAreaFilter(),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            icon: Icons.calendar_today,
                            label: _filterDateRange != null
                              ? '${_filterDateRange!.start.month}/${_filterDateRange!.start.day}〜${_filterDateRange!.end.month}/${_filterDateRange!.end.day}'
                              : '日付',
                            isActive: _filterDateRange != null,
                            onTap: () => _showDateFilter(),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        // 過去の大会表示トグル
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
                        if (hasActiveFilter) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _filterType = 'すべて'; _filterArea = 'すべて';
                              _filterDateRange = null; _showPastTournaments = false;
                            }),
                            child: Row(children: [
                              Icon(Icons.refresh, size: 14, color: AppTheme.error),
                              const SizedBox(width: 4),
                              Text('フィルターをリセット', style: TextStyle(fontSize: 12, color: AppTheme.error)),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // ── コンテンツ ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _showTournaments ? _buildTournamentList(true) : _buildRecruitList(),
                _buildTournamentList(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon, required String label, required bool isActive,
    Color? color, required VoidCallback onTap,
  }) {
    final activeColor = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? activeColor : Colors.grey[300]!, width: isActive ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isActive ? activeColor : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? activeColor : AppTheme.textSecondary,
          )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: isActive ? activeColor : AppTheme.textHint),
        ]),
      ),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('種別で絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...['すべて', '混合', 'メンズ', 'レディース'].map((t) => ListTile(
            leading: t == 'すべて'
                ? const Icon(Icons.all_inclusive, color: AppTheme.textSecondary)
                : Icon(Icons.circle, color: _typeColor(t), size: 18),
            title: Text(t, style: TextStyle(
              fontWeight: _filterType == t ? FontWeight.bold : FontWeight.normal,
              color: _filterType == t ? _typeColor(t) : AppTheme.textPrimary,
            )),
            trailing: _filterType == t ? Icon(Icons.check, color: _typeColor(t)) : null,
            onTap: () { setState(() => _filterType = t); Navigator.pop(ctx); },
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showAreaFilter() {
    final areas = ['すべて', '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄'];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('エリアで絞り込み', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Flexible(child: ListView(shrinkWrap: true, children: areas.map((a) => ListTile(
            leading: a == 'すべて'
                ? const Icon(Icons.public, color: AppTheme.textSecondary)
                : const Icon(Icons.location_on, color: AppTheme.primaryColor),
            title: Text(a, style: TextStyle(fontWeight: _filterArea == a ? FontWeight.bold : FontWeight.normal)),
            trailing: _filterArea == a ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
            onTap: () { setState(() => _filterArea = a); Navigator.pop(ctx); },
          )).toList())),
          const SizedBox(height: 8),
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
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(
          primary: AppTheme.primaryColor, onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (range != null) setState(() => _filterDateRange = range);
  }

  Widget _buildMiniToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        )),
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
        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final organizerId = data['organizerId'] ?? '';
          final status = data['status'] ?? '準備中';
          final isFollowing = _followingIds.contains(organizerId) || organizerId == _currentUser?.uid;

          // 開催中・決勝中は表示しない
          if (status == '開催中' || status == '決勝中') return false;

          if (friendsOnly) {
            if (!isFollowing) return false;
          } else {
            if (isFollowing) return false;
          }

          // デフォルトは募集中のみ、フィルターで終了も表示
          if (status == '終了' && !_showPastTournaments) return false;
          if (status == '準備中') return false;

          // テキスト検索
          if (query.isNotEmpty) {
            final title = (data['title'] ?? '').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().toLowerCase();
            final type = (data['type'] ?? '').toString().toLowerCase();
            if (!title.contains(query) && !location.contains(query) && !type.contains(query)) return false;
          }
          // 種別フィルター
          if (_filterType != 'すべて') {
            if ((data['type'] ?? '') != _filterType) return false;
          }
          // エリアフィルター
          if (_filterArea != 'すべて') {
            final loc = (data['location'] ?? '').toString();
            final area = (data['area'] ?? '').toString();
            if (!loc.contains(_filterArea) && !area.contains(_filterArea)) return false;
          }
          // 日付フィルター
          if (_filterDateRange != null) {
            final d = _parseDate(data['date'] ?? '');
            if (d == null) return false;
            if (d.isBefore(_filterDateRange!.start) || d.isAfter(_filterDateRange!.end)) return false;
          }
          return true;
        }).toList();

        // 大会日が近い順
        filtered.sort((a, b) {
          final da = _parseDate((a.data() as Map<String, dynamic>)['date'] ?? '') ?? DateTime(2099);
          final db = _parseDate((b.data() as Map<String, dynamic>)['date'] ?? '') ?? DateTime(2099);
          final now = DateTime.now();
          return (da.difference(now).inDays).abs().compareTo((db.difference(now).inDays).abs());
        });

        if (filtered.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(friendsOnly ? Icons.emoji_events_outlined : Icons.explore_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(friendsOnly ? 'フォロー中の主催者の大会はありません' : '新しい大会が見つかりません',
                style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(friendsOnly ? '主催者をフォローすると\nここに大会が表示されます' : 'フォロー外の主催者の大会が\nここに表示されます',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
          ]));
        }

        return Column(children: [
          if (!friendsOnly)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.textHint),
                const SizedBox(width: 6),
                Expanded(child: Text('フォローしていない主催者の大会です。エントリーにはフォローが必要です。',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint))),
              ]),
            ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTournamentCard(filtered[index]),
            ),
          )),
        ]);
      },
    );
  }

  // ━━━ 大会カード ━━━
  Widget _buildTournamentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '無名大会';
    final date = data['date'] ?? '';
    final location = data['location'] ?? '';
    final status = data['status'] ?? '準備中';
    final format = data['format'] ?? '';
    final type = data['type'] ?? '';
    final entryFee = data['entryFee'] ?? '';
    final currentTeams = data['currentTeams'] ?? 0;
    final maxTeams = data['maxTeams'] ?? 8;
    final organizerId = data['organizerId'] ?? '';
    final organizerName = data['organizerName'] ?? '不明';
    final deadline = data['deadline'] ?? '';
    final isFollowing = _followingIds.contains(organizerId) || organizerId == _currentUser?.uid;

    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '満員': statusColor = AppTheme.error; break;
      case '終了': statusColor = AppTheme.textSecondary; break;
      default: statusColor = AppTheme.textSecondary;
    }

    // 日付パース
    String day = '';
    String month = '';
    String weekday = '';
    try {
      final parts = date.split('/');
      if (parts.length >= 3) {
        month = '${int.parse(parts[1])}月';
        day = parts[2];
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = weekdays[d.weekday - 1];
      }
    } catch (_) {}

    
    final typeColor = _typeColor(type);
    final progress = maxTeams > 0 ? currentTeams / maxTeams : 0.0;
    String formatDisplay = format.toString().replaceAll('4人制', '').trim();

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {
          'id': doc.id, 'name': title, 'date': date, 'venue': location,
          'courts': 0, 'type': type, 'format': format,
          'currentTeams': currentTeams, 'maxTeams': maxTeams,
          'fee': entryFee, 'status': status, 'statusColor': statusColor,
          'deadline': deadline, 'organizer': organizerName, 'isFollowing': isFollowing,
        })));
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 左: 日付（月ごとの色）+ 種別バッジ
            Column(children: [
              Container(
                width: 52, padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text(month, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                  Text(day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
                  if (weekday.isNotEmpty) Text('($weekday)', style: TextStyle(fontSize: 10, color: statusColor)),
                ]),
              ),
              const SizedBox(height: 6),
              if (type.isNotEmpty)
                Container(
                  width: 52, padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(type, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor)),
                ),
            ]),
            const SizedBox(width: 14),
            // 右: 情報
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text(organizerName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (!isFollowing) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.textHint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('未フォロー', style: TextStyle(fontSize: 9, color: AppTheme.textHint)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Flexible(child: Text(location,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
              if (formatDisplay.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.sports_volleyball, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                  Text(formatDisplay, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
              ],
              if (entryFee.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.payments, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                  Text(entryFee.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
              ],
              if (deadline.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.timer_outlined, size: 13, color: AppTheme.warning), const SizedBox(width: 4),
                  Text('締切: $deadline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.groups, size: 14, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text('$currentTeams/$maxTeams', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(width: 10),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress, backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? AppTheme.error : progress >= 0.8 ? AppTheme.warning : AppTheme.success),
                    minHeight: 4),
                )),
              ]),
            ])),
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400])),
          ]),
        ),
      ),
    );
  }

  // ━━━ メンバー募集リスト ━━━
  Widget _buildRecruitList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('recruitments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('メンバー募集はまだありません', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildRecruitCard(data));
          },
        );
      },
    );
  }

  Widget _buildRecruitCard(Map<String, dynamic> data) {
    final nickname = data['nickname'] ?? '不明';
    final experience = data['experience'] ?? '';
    final tournamentName = data['tournamentName'] ?? '';
    final tournamentDate = data['tournamentDate'] ?? '';
    final recruitCount = data['recruitCount'] ?? 0;
    final comment = data['comment'] ?? '';
    final recruiterId = data['userId'] ?? '';
    final isFollowing = _followingIds.contains(recruiterId) || recruiterId == _currentUser?.uid;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 22, backgroundColor: AppTheme.accentColor.withOpacity(0.12),
              child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                  style: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              if (recruitCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('あと${recruitCount}人', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error)),
                ),
            ]),
            if (experience.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('競技歴 $experience', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            if (tournamentName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.emoji_events, size: 13, color: AppTheme.primaryColor), const SizedBox(width: 4),
                Flexible(child: Text(tournamentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor))),
                if (tournamentDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(tournamentDate, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ]),
            ],
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: isFollowing ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(isFollowing ? '応募する' : 'フォローすると応募できます',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isFollowing ? Colors.white : AppTheme.textSecondary)),
            )),
          ])),
        ]),
      ),
    );
  }
}
