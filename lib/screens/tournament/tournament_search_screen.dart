import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../services/bookmark_notification_service.dart';
import 'tournament_detail_screen.dart';
import '../chat/chat_screen.dart';

class TournamentSearchScreen extends StatefulWidget {
  const TournamentSearchScreen({super.key});
  @override
  State<TournamentSearchScreen> createState() => _TournamentSearchScreenState();
}

class _TournamentSearchScreenState extends State<TournamentSearchScreen>
    with TickerProviderStateMixin {
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  Set<String> _followingIds = {};
  Set<String> _bookmarkedTournaments = {};
  Set<String> _bookmarkedRecruits = {};

  // ── Top-level swipeable page (0=tournament, 1=recruitment) ──
  late PageController _pageController;
  int _currentPage = 0;

  // ── Sub-tab: friends-only toggle ──
  bool _friendsOnly = true;

  // ── Saved mode ──
  bool _isSavedMode = false;
  bool _savedFilterTournament = true;
  bool _savedFilterRecruitment = true;

  // ── Filters ──
  bool _showFilter = false;
  String _filterType = 'すべて';
  String _filterArea = 'すべて';
  DateTimeRange? _filterDateRange;
  bool _showPastTournaments = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _pageController.addListener(_onPageScroll);
    _loadFollowing();
    _loadBookmarks();
  }

  void _onPageScroll() {
    final page = _pageController.page;
    if (page != null) {
      final rounded = page.round();
      if (rounded != _currentPage) {
        setState(() => _currentPage = rounded);
      }
    }
  }

  Future<void> _loadFollowing() async {
    final user = _currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('following').get();
    if (mounted) {
      setState(() {
        _followingIds = snap.docs.map((d) => d.id).toSet();
      });
    }
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
      if (_bookmarkedTournaments.contains(docId)) {
        _bookmarkedTournaments.remove(docId);
      } else {
        _bookmarkedTournaments.add(docId);
      }
    });
  }

  Future<void> _toggleRecruitBookmark(String targetId, Map<String, dynamic> meta) async {
    final user = _currentUser;
    if (user == null) return;
    await BookmarkNotificationService.toggleBookmark(
        uid: user.uid, targetId: targetId, type: 'recruitment', metadata: meta);
    setState(() {
      if (_bookmarkedRecruits.contains(targetId)) {
        _bookmarkedRecruits.remove(targetId);
      } else {
        _bookmarkedRecruits.add(targetId);
      }
    });
  }

  Future<void> _applyToRecruitment(String recruiterId, String recruiterName, String tournamentName) async {
    if (_currentUser == null || recruiterId == _currentUser!.uid) return;
    final myUid = _currentUser!.uid;

    // 既存のDMを探す
    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('members', arrayContains: myUid)
        .get();

    String? chatId;
    for (final doc in existing.docs) {
      final members = List<String>.from(doc['members'] ?? []);
      if (members.contains(recruiterId)) {
        chatId = doc.id;
        break;
      }
    }

    // DMが無ければ作成
    if (chatId == null) {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      final myName = (myDoc.data()?['nickname'] as String?) ?? '自分';

      final ref = await FirebaseFirestore.instance.collection('chats').add({
        'type': 'dm',
        'members': [myUid, recruiterId],
        'memberNames': {myUid: myName, recruiterId: recruiterName},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = ref.id;
    }

    // 自動メッセージを送信
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final myName = (myDoc.data()?['nickname'] as String?) ?? '自分';
    final messageText = tournamentName.isNotEmpty
        ? '「$tournamentName」のメンバー募集に応募します！よろしくお願いします。'
        : 'メンバー募集に応募します！よろしくお願いします。';

    await FirebaseFirestore.instance
        .collection('chats').doc(chatId).collection('messages').add({
      'senderId': myUid,
      'senderName': myName,
      'type': 'text',
      'text': messageText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'lastMessage': messageText,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId!,
          chatTitle: recruiterName,
          chatType: 'dm',
          otherUserId: recruiterId,
        ),
      ));
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // BUILD
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (_showFilter && !_isSavedMode) _buildFilterPanel(),
          Expanded(child: _buildContent()),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _isSavedMode = !_isSavedMode),
        backgroundColor: _isSavedMode ? AppTheme.primaryColor : AppTheme.accentColor,
        child: Icon(
          _isSavedMode ? Icons.search : Icons.bookmark,
          color: Colors.white,
        ),
      ),
    );
  }

  // ━━━ ヘッダー ━━━
  Widget _buildHeader() {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            _isSavedMode ? '保存済み' : 'さがす',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── メイン切替タブ (swipeable indicators) ──
        if (!_isSavedMode) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _buildModeTab('大会をさがす', Icons.emoji_events_outlined, 0)),
              const SizedBox(width: 8),
              Expanded(child: _buildModeTab('メンバーをさがす', Icons.people_outline, 1)),
            ]),
          ),
          const SizedBox(height: 10),

          // ── フォロー中 / みんなの (tappable toggle) ──
          _buildSubTabToggle(),
          const SizedBox(height: 10),

          // ── 検索バー + フィルターボタン ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _currentPage == 0
                          ? '大会名・会場名で検索'
                          : '名前・大会名で検索',
                      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
                      filled: true,
                      fillColor: AppTheme.backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showFilter = !_showFilter),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter ? AppTheme.primaryColor : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(Icons.tune, size: 20,
                        color: _hasActiveFilter ? Colors.white : AppTheme.textSecondary),
                    if (_hasActiveFilter)
                      Positioned(right: 6, top: 6, child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                      )),
                  ]),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Mode tab for swipeable top-level pages ──
  Widget _buildModeTab(String label, IconData icon, int page) {
    final isSelected = _currentPage == page;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: isSelected ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          )),
        ]),
      ),
    );
  }

  // ── Sub-tab toggle (フォロー中 / みんなの) ──
  Widget _buildSubTabToggle() {
    final allLabel = _currentPage == 0 ? 'みんなの大会' : 'みんなのメンバー';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        Expanded(child: _subTabButton('フォロー中', true)),
        Expanded(child: _subTabButton(allLabel, false)),
      ]),
    );
  }

  Widget _subTabButton(String label, bool isFriendsValue) {
    final isActive = _friendsOnly == isFriendsValue;
    return GestureDetector(
      onTap: () => setState(() => _friendsOnly = isFriendsValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
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
            _filterChip(
              Icons.sports_volleyball,
              _filterType == 'すべて' ? '種別' : _filterType,
              _filterType != 'すべて',
              color: _filterType != 'すべて' ? _typeColor(_filterType) : null,
              onTap: _showTypeFilter,
            ),
            const SizedBox(width: 8),
            _filterChip(
              Icons.location_on_outlined,
              _filterArea == 'すべて' ? 'エリア' : _filterArea,
              _filterArea != 'すべて',
              onTap: _showAreaFilter,
            ),
            const SizedBox(width: 8),
            _filterChip(
              Icons.calendar_month_outlined,
              _filterDateRange != null
                  ? '${_filterDateRange!.start.month}/${_filterDateRange!.start.day}〜${_filterDateRange!.end.month}/${_filterDateRange!.end.day}'
                  : '日付',
              _filterDateRange != null,
              onTap: _showDateFilter,
            ),
          ]),
        ),
        if (_currentPage == 0) ...[
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
              _filterType = 'すべて';
              _filterArea = 'すべて';
              _filterDateRange = null;
              _showPastTournaments = false;
            }),
            child: Row(children: [
              Icon(Icons.refresh, size: 14, color: AppTheme.error),
              const SizedBox(width: 4),
              Text('フィルターをリセット',
                  style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600)),
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
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? c : AppTheme.textSecondary,
          )),
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
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: c.withValues(alpha: 0.12),
                child: Icon(t == 'すべて' ? Icons.all_inclusive : Icons.circle, color: c, size: 14),
              ),
              title: Text(t, style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? c : AppTheme.textPrimary,
              )),
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
            leading: Icon(
              a == 'すべて' ? Icons.public : Icons.location_on_outlined,
              color: _filterArea == a ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 20,
            ),
            title: Text(a, style: TextStyle(
              fontWeight: _filterArea == a ? FontWeight.bold : FontWeight.normal,
              color: _filterArea == a ? AppTheme.primaryColor : AppTheme.textPrimary,
            )),
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
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) setState(() => _filterDateRange = range);
  }

  // ━━━ コンテンツ ━━━
  Widget _buildContent() {
    if (_isSavedMode) return _buildSavedList();

    // Swipeable PageView for tournament / recruitment
    return PageView(
      controller: _pageController,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      children: [
        _buildTournamentList(_friendsOnly),
        _buildRecruitList(_friendsOnly),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 保存済み (Saved) - Improved UI
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSavedList() {
    final user = _currentUser;
    if (user == null) {
      return const Center(
        child: Text('ログインしてください', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('bookmarks').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final allDocs = snap.data?.docs ?? [];
        final tDocs = allDocs.where((d) => (d.data() as Map)['type'] == 'tournament').toList();
        final rDocs = allDocs.where((d) => (d.data() as Map)['type'] == 'recruitment').toList();

        if (allDocs.isEmpty) {
          return _buildSavedEmptyState();
        }

        // Build filtered items
        final List<DocumentSnapshot> visibleItems = [];
        if (_savedFilterTournament) visibleItems.addAll(tDocs);
        if (_savedFilterRecruitment) visibleItems.addAll(rDocs);

        return Column(children: [
          // ── Gradient header with counts ──
          _buildSavedHeader(tDocs.length, rDocs.length),

          // ── Filter toggle chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _savedToggleChip(
                icon: Icons.emoji_events,
                label: '大会',
                count: tDocs.length,
                isActive: _savedFilterTournament,
                color: AppTheme.primaryColor,
                onTap: () => setState(() => _savedFilterTournament = !_savedFilterTournament),
              ),
              const SizedBox(width: 10),
              _savedToggleChip(
                icon: Icons.people,
                label: 'メンバー募集',
                count: rDocs.length,
                isActive: _savedFilterRecruitment,
                color: AppTheme.accentColor,
                onTap: () => setState(() => _savedFilterRecruitment = !_savedFilterRecruitment),
              ),
            ]),
          ),

          // ── List ──
          Expanded(
            child: visibleItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'フィルターを調整してください',
                          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: visibleItems.length,
                    itemBuilder: (ctx, i) {
                      final doc = visibleItems[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = data['type'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.error.withValues(alpha: 0.05), AppTheme.error.withValues(alpha: 0.15)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, color: AppTheme.error, size: 24),
                                const SizedBox(height: 2),
                                Text('削除', style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('保存を解除', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                content: const Text('このブックマークを削除しますか？', style: TextStyle(fontSize: 14)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('削除', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                          },
                          onDismissed: (_) async {
                            await doc.reference.delete();
                            _loadBookmarks();
                          },
                          child: type == 'tournament'
                              ? _buildSavedTournamentCard(doc)
                              : _buildSavedRecruitCard(doc),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }

  // ── Gradient header with bookmark counts ──
  Widget _buildSavedHeader(int tournamentCount, int recruitCount) {
    final total = tournamentCount + recruitCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.bookmark, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$total件保存中',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.emoji_events, size: 13, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                '大会 $tournamentCount件',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(width: 12),
              Icon(Icons.people, size: 13, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                '募集 $recruitCount件',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Toggle chip for saved filter ──
  Widget _savedToggleChip({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.5) : Colors.grey[300]!,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: isActive ? color : AppTheme.textHint),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? color : AppTheme.textHint,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Better empty state for saved view ──
  Widget _buildSavedEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bookmark_outline, size: 48, color: AppTheme.accentColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          const Text(
            '保存した大会・募集はありません',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            '気になる大会やメンバー募集のブックマークアイコンをタップして、ここに保存しましょう。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isSavedMode = false),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('大会をさがす'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: Size.zero,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Saved tournament card (improved) ──
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
        month = '${int.parse(p[1])}月';
        day = p[2];
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
            }),
          ));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: alerts.isNotEmpty ? AppTheme.warning.withValues(alpha: 0.4) : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.7), width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _dateBlock(month, day, weekday, sc, tournamentType, tc),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    bm['title'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Flexible(child: Text(
                      bm['location'] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc),
                      ),
                    ),
                  ],
                  if (alerts.contains('deadline'))
                    _alertBadge(Icons.warning_amber, '締切が近い！', AppTheme.warning),
                  if (alerts.contains('slots'))
                    _alertBadge(Icons.group, '残り枠わずか！', AppTheme.error),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Saved recruit card (improved) ──
  Widget _buildSavedRecruitCard(DocumentSnapshot bmDoc) {
    final bm = bmDoc.data() as Map<String, dynamic>;
    final nickname = bm['nickname'] ?? '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.7), width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
                child: Text(
                  nickname.isNotEmpty ? nickname[0] : '?',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  nickname,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                if ((bm['tournamentName'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.emoji_events, size: 13, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Flexible(child: Text(
                      '${bm['tournamentName']} ${bm['tournamentDate'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ],
              ])),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right, size: 18, color: AppTheme.accentColor),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Standard empty state used by search lists ──
  Widget _emptyState(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 60, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
      if (sub.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(sub, style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
      ],
    ]));
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 大会リスト
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
            friendsOnly ? 'フォロー中の大会はありません' : '大会が見つかりません',
            '',
          );
        }

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
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
        month = '${int.parse(p[1])}月';
        day = p[2];
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
            decoration: BoxDecoration(
              color: tc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // メンバー募集リスト
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
              child: Text(
                nickname.isNotEmpty ? nickname[0] : '?',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(nickname,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                if (recruitCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'あと$recruitCount人',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
                    ),
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
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(children: [
                Icon(Icons.emoji_events, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tournamentName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                  if (tournamentDate.isNotEmpty)
                    Text(tournamentDate,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ])),
              ]),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: isFollowing ? () => _applyToRecruitment(recruiterId, nickname, tournamentName) : null,
              icon: Icon(isFollowing ? Icons.send : Icons.person_add, size: 15),
              label: Text(
                isFollowing ? '応募する' : 'フォローして応募',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
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
