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
    _loadMyTournaments();
  }

  Future<void> _loadMyTournaments() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final tournSnap = await FirebaseFirestore.instance.collection('tournaments').get();
    final upcoming = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (final doc in tournSnap.docs) {
      final data = doc.data();
      final isOrganizer = data['organizerId'] == uid;
      final entriesSnap = await doc.reference.collection('entries')
          .where('enteredBy', isEqualTo: uid).limit(1).get();
      final isEntered = entriesSnap.docs.isNotEmpty;
      if (!isOrganizer && !isEntered) continue;

      final teamName = isEntered ? (entriesSnap.docs.first.data()['teamName'] ?? '') : '主催者';
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

    if (mounted) setState(() { _upcoming = upcoming; _past = past; _loading = false; });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToDetail(Map<String, dynamic> t) {
    final status = t['status'] ?? '準備中';
    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      default: statusColor = AppTheme.textSecondary;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(
      tournament: {
        'id': t['id'], 'name': t['title'] ?? '', 'date': t['date'] ?? '',
        'venue': t['location'] ?? '', 'courts': t['courts'] ?? 0,
        'type': t['type'] ?? '', 'format': t['format'] ?? '',
        'currentTeams': t['currentTeams'] ?? 0, 'maxTeams': t['maxTeams'] ?? 8,
        'fee': t['entryFee'] ?? '', 'status': status, 'statusColor': statusColor,
        'deadline': '', 'organizer': t['organizerName'] ?? '',
        'isFollowing': true, 'organizerId': t['organizerId'] ?? '',
        'rules': t['rules'] ?? {}, 'venueAddress': t['venueAddress'] ?? '',
        'location': t['location'] ?? '',
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('予定'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.upcoming, size: 18), const SizedBox(width: 6),
              Text('開催予定 ${_upcoming.length}'),
            ])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.history, size: 18), const SizedBox(width: 6),
              Text('過去の大会 ${_past.length}'),
            ])),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(controller: _tabController, children: [
              _buildUpcomingTab(),
              _buildPastTab(),
            ]),
    );
  }

  Widget _buildUpcomingTab() {
    if (_upcoming.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_note_outlined, size: 80, color: AppTheme.textHint),
        const SizedBox(height: 16),
        const Text('参加予定の大会はありません', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('大会を検索してエントリーしましょう！', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadMyTournaments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_upcoming.isNotEmpty) ...[
            _buildNextTournamentCard(_upcoming.first),
            const SizedBox(height: 20),
          ],
          ..._upcoming.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildUpcomingCard(t),
          )),
        ],
      ),
    );
  }

  Widget _buildNextTournamentCard(Map<String, dynamic> t) {
    final dateStr = t['date'] ?? '';
    int daysLeft = 0;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        daysLeft = d.difference(DateTime.now()).inDays;
        if (daysLeft < 0) daysLeft = 0;
      }
    } catch (_) {}
    final status = t['status'] ?? '';

    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(daysLeft == 0 ? '本日' : 'あと${daysLeft}日', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
            ),
            const Spacer(),
            const Text('次の大会', style: TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
          const SizedBox(height: 14),
          Text(t['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.white70), const SizedBox(width: 6),
            Text(dateStr, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70), const SizedBox(width: 6),
            Text(t['location'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.groups_outlined, size: 14, color: Colors.white70), const SizedBox(width: 6),
            Text('${t['teamName'] ?? ''} · ${t['format'] ?? ''}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.2), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: Text(t['isOrganizer'] == true ? '主催' : status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> t) {
    final status = t['status'] ?? '';
    final isOrganizer = t['isOrganizer'] == true;
    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      default: statusColor = AppTheme.textSecondary;
    }
    final dateStr = t['date'] ?? '';
    String day = '';
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) day = parts[2];
    } catch (_) {}

    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(day, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(isOrganizer ? '主催' : status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Flexible(child: Text(t['location'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.groups_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text(t['teamName'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 12),
                Icon(Icons.sports_volleyball, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text(t['format'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ])),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }

  Widget _buildPastTab() {
    if (_past.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, size: 80, color: AppTheme.textHint),
        const SizedBox(height: 16),
        const Text('過去の大会はありません', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('大会に参加すると履歴がここに表示されます', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadMyTournaments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[200]!)),
            child: Row(children: [
              Expanded(child: _buildSummaryItem('参加大会', '${_past.length}', AppTheme.primaryColor)),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(child: _buildSummaryItem('主催', '${_past.where((t) => t['isOrganizer'] == true).length}', AppTheme.accentColor)),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(child: _buildSummaryItem('出場', '${_past.where((t) => t['isEntered'] == true).length}', AppTheme.success)),
            ]),
          ),
          const SizedBox(height: 20),
          ..._past.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPastCard(t),
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    ]);
  }

  Widget _buildPastCard(Map<String, dynamic> t) {
    return GestureDetector(
      onTap: () => _navigateToDetail(t),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.emoji_events_outlined, color: AppTheme.textSecondary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text(t['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Flexible(child: Text(t['location'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppTheme.textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('結果を見る', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }
}
