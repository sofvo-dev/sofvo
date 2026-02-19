import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../tournament/tournament_detail_screen.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});
  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadMyTournaments();
  }

  Future<void> _loadMyTournaments() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    if (mounted) setState(() => _loading = true);
    final tournSnap =
        await FirebaseFirestore.instance.collection('tournaments').get();
    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (final doc in tournSnap.docs) {
      final data = doc.data();
      final isOrganizer = data['organizerId'] == uid;
      final entriesSnap = await doc.reference
          .collection('entries')
          .where('enteredBy', isEqualTo: uid)
          .limit(1)
          .get();
      final isEntered = entriesSnap.docs.isNotEmpty;
      if (!isOrganizer && !isEntered) continue;

      final teamName = isEntered
          ? (entriesSnap.docs.first.data()['teamName'] ?? '')
          : '主催者';
      final status = data['status'] ?? '準備中';
      final entry = {
        ...data,
        'id': doc.id,
        'teamName': teamName,
        'isOrganizer': isOrganizer,
        'isEntered': isEntered,
      };

      if (status == '終了') {
        past.add(entry);
      } else {
        upcoming.add(entry);
      }
    }

    upcoming.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
    past.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    if (mounted) {
      setState(() {
        _upcoming = upcoming;
        _past = past;
        _loading = false;
      });
    }
  }

  void _navigateToDetail(Map<String, dynamic> t) {
    final status = t['status'] ?? '準備中';
    Color statusColor;
    switch (status) {
      case '募集中':
        statusColor = AppTheme.success;
        break;
      case '開催中':
        statusColor = AppTheme.primaryColor;
        break;
      case '決勝中':
        statusColor = Colors.amber;
        break;
      default:
        statusColor = AppTheme.textSecondary;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TournamentDetailScreen(
                  tournament: {
                    'id': t['id'],
                    'name': t['title'] ?? '',
                    'date': t['date'] ?? '',
                    'venue': t['location'] ?? '',
                    'courts': t['courts'] ?? 0,
                    'type': t['type'] ?? '',
                    'format': t['format'] ?? '',
                    'currentTeams': t['currentTeams'] ?? 0,
                    'maxTeams': t['maxTeams'] ?? 8,
                    'fee': t['entryFee'] ?? '',
                    'status': status,
                    'statusColor': statusColor,
                    'deadline': '',
                    'organizer': t['organizerName'] ?? '',
                    'isFollowing': true,
                    'organizerId': t['organizerId'] ?? '',
                    'rules': t['rules'] ?? {},
                    'venueAddress': t['venueAddress'] ?? '',
                    'location': t['location'] ?? '',
                  },
                )));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ━━━ ヘッダー ━━━
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('予定',
            style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          _buildTab('開催予定', 0, Icons.upcoming),
          const SizedBox(width: 8),
          _buildTab('過去の大会', 1, Icons.history),
        ]),
        const SizedBox(height: 1),
        Container(height: 1, color: Colors.grey[100]),
      ]),
    );
  }

  Widget _buildTab(String label, int index, IconData icon) {
    final isSelected = _tabController.index == index;
    final count = index == 0 ? _upcoming.length : _past.length;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 15,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary)),
          if (!_loading) ...[
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary)),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpcomingTab(),
                      _buildPastTab(),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  // ━━━ 開催予定タブ ━━━
  Widget _buildUpcomingTab() {
    if (_upcoming.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMyTournaments,
        child: ListView(children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text('参加予定の大会はありません',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('大会を検索してエントリーしましょう！',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textHint)),
                  ]),
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTournaments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildNextHighlight(_upcoming.first),
          const SizedBox(height: 20),
          if (_upcoming.length > 1) ...[
            _sectionHeader(Icons.calendar_month, 'すべての予定', _upcoming.length),
            const SizedBox(height: 10),
            ..._upcoming.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildUpcomingCard(t),
                )),
          ],
        ],
      ),
    );
  }

  // ━━━ 次の大会ハイライト ━━━
  Widget _buildNextHighlight(Map<String, dynamic> t) {
    final dateStr = t['date'] ?? '';
    int daysLeft = -1;
    String month = '', day = '', weekday = '';
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
        daysLeft = d.difference(DateTime.now()).inDays;
        if (daysLeft < 0) daysLeft = 0;
        month = '${int.parse(parts[1])}月';
        day = parts[2];
        const w = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = w[d.weekday - 1];
      }
    } catch (_) {}
    final status = t['status'] ?? '';
    final isOrganizer = t['isOrganizer'] == true;
    final roleLabel = isOrganizer ? '主催' : status;
    final roleColor = isOrganizer ? AppTheme.accentColor : AppTheme.success;

    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          // 上部ヘッダー帯
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(Icons.star_rounded,
                  size: 15, color: AppTheme.primaryColor),
              const SizedBox(width: 5),
              Text('次の大会',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: daysLeft == 0
                      ? AppTheme.error.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined,
                      size: 13,
                      color: daysLeft == 0
                          ? AppTheme.error
                          : AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                      daysLeft == 0
                          ? '本日！'
                          : daysLeft < 0
                              ? '日程未定'
                              : 'あと$daysLeft日',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: daysLeft == 0
                              ? AppTheme.error
                              : AppTheme.primaryColor)),
                ]),
              ),
            ]),
          ),
          // 本体
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 日付ブロック
              _dateBlock(month, day, weekday, AppTheme.primaryColor),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    _infoRow(Icons.location_on_outlined, t['location'] ?? ''),
                    const SizedBox(height: 4),
                    _infoRow(Icons.groups_outlined,
                        '${t['teamName'] ?? ''}  ·  ${t['format'] ?? ''}'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(roleLabel,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: roleColor)),
                    ),
                  ])),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ━━━ 開催予定カード ━━━
  Widget _buildUpcomingCard(Map<String, dynamic> t) {
    final status = t['status'] ?? '';
    final isOrganizer = t['isOrganizer'] == true;
    final dateStr = t['date'] ?? '';
    String month = '', day = '', weekday = '';
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) {
        month = '${int.parse(parts[1])}月';
        day = parts[2];
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
        const w = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = w[d.weekday - 1];
      }
    } catch (_) {}

    Color sc;
    switch (status) {
      case '募集中':
        sc = AppTheme.success;
        break;
      case '開催中':
        sc = AppTheme.primaryColor;
        break;
      case '決勝中':
        sc = Colors.amber;
        break;
      default:
        sc = AppTheme.textSecondary;
    }
    final roleLabel = isOrganizer ? '主催' : status;
    final roleColor = isOrganizer ? AppTheme.accentColor : sc;

    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dateBlock(month, day, weekday, sc),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(t['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(roleLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: roleColor)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_outlined, t['location'] ?? ''),
                  const SizedBox(height: 4),
                  _infoRow(
                      Icons.groups_outlined, t['teamName'] ?? ''),
                ])),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }

  // ━━━ 過去の大会タブ ━━━
  Widget _buildPastTab() {
    if (_past.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMyTournaments,
        child: ListView(children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text('過去の大会はありません',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('大会に参加すると履歴がここに表示されます',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textHint)),
                  ]),
            ),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTournaments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // サマリーカード
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: _summaryItem(
                      '参加大会', '${_past.length}', AppTheme.primaryColor)),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                  child: _summaryItem(
                      '主催',
                      '${_past.where((t) => t['isOrganizer'] == true).length}',
                      AppTheme.accentColor)),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                  child: _summaryItem(
                      '出場',
                      '${_past.where((t) => t['isEntered'] == true).length}',
                      AppTheme.success)),
            ]),
          ),
          const SizedBox(height: 20),
          _sectionHeader(Icons.history, '参加履歴', _past.length),
          const SizedBox(height: 10),
          ..._past.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPastCard(t),
              )),
        ],
      ),
    );
  }

  // ━━━ 過去の大会カード ━━━
  Widget _buildPastCard(Map<String, dynamic> t) {
    final dateStr = t['date'] ?? '';
    String month = '', day = '', weekday = '';
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) {
        month = '${int.parse(parts[1])}月';
        day = parts[2];
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
        const w = ['月', '火', '水', '木', '金', '土', '日'];
        weekday = w[d.weekday - 1];
      }
    } catch (_) {}
    final isOrganizer = t['isOrganizer'] == true;

    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _dateBlock(month, day, weekday, AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(t['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(isOrganizer ? '主催' : '出場',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_outlined, t['location'] ?? ''),
                  const SizedBox(height: 4),
                  _infoRow(Icons.groups_outlined, t['teamName'] ?? ''),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 13, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text('結果を見る',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor)),
                      ]),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 20, color: Colors.grey[400]),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }

  // ━━━ 共通ウィジェット ━━━
  Widget _dateBlock(String month, String day, String weekday, Color color) {
    return SizedBox(
      width: 52,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(month,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          Text(day,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.1)),
          if (weekday.isNotEmpty)
            Text('($weekday)',
                style: TextStyle(fontSize: 10, color: color)),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 13, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Flexible(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _sectionHeader(IconData icon, String title, int count) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.primaryColor),
      const SizedBox(width: 6),
      Text('$title ($count件)',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor)),
    ]);
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
    ]);
  }
}
