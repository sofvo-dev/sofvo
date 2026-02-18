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
  bool _showTournaments = true; // true=大会, false=メンバー募集

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  bool get _isFriends => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
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
          onTap: (_) => setState(() {}),
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
          // ── 大会/メンバー募集 トグル（左寄せ） + 検索 ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _buildMiniToggle('大会', _showTournaments, () => setState(() => _showTournaments = true)),
              const SizedBox(width: 8),
              _buildMiniToggle('メンバー募集', !_showTournaments, () => setState(() => _showTournaments = false)),
              const Spacer(),
            ]),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _showTournaments ? '大会名・会場名で検索' : 'メンバー募集を検索',
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
          // ── コンテンツ ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 友達の大会
                _showTournaments ? _buildTournamentList(true) : _buildRecruitList(true),
                // みんなの大会
                _showTournaments ? _buildTournamentList(false) : _buildRecruitList(false),
              ],
            ),
          ),
        ],
      ),
    );
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

  // ━━━ 大会リスト（予定タブ風カード） ━━━
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
          final isEntered = _enteredTournamentIds.contains(doc.id);

          if (friendsOnly) {
            if (!isFollowing) return false;
            if ((status == '開催中' || status == '決勝中') && !isEntered) return false;
          } else {
            if (isFollowing) return false;
            if (status != '募集中' && status != '終了') return false;
          }
          if (query.isNotEmpty) {
            final title = (data['title'] ?? '').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().toLowerCase();
            final type = (data['type'] ?? '').toString().toLowerCase();
            return title.contains(query) || location.contains(query) || type.contains(query);
          }
          return true;
        }).toList();

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

        if (!friendsOnly) {
          return Column(children: [
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
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTournamentCard(filtered[index]),
          ),
        );
      },
    );
  }

  // ━━━ 予定タブ風 大会カード ━━━
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
    final courts = data['courts'] ?? 0;
    final organizerId = data['organizerId'] ?? '';
    final organizerName = data['organizerName'] ?? '不明';
    final isFollowing = _followingIds.contains(organizerId) || organizerId == _currentUser?.uid;

    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '満員': statusColor = AppTheme.error; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      case '終了': statusColor = AppTheme.textSecondary; break;
      default: statusColor = AppTheme.textSecondary;
    }

    // 日付から日を抽出
    String day = '';
    String month = '';
    try {
      final parts = date.split('/');
      if (parts.length >= 3) { month = '${int.parse(parts[1])}月'; day = parts[2]; }
    } catch (_) {}

    final progress = maxTeams > 0 ? currentTeams / maxTeams : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {
          'id': doc.id, 'name': title, 'date': date, 'venue': location,
          'courts': courts, 'type': type, 'format': format,
          'currentTeams': currentTeams, 'maxTeams': maxTeams,
          'fee': entryFee, 'status': status, 'statusColor': statusColor,
          'deadline': '', 'organizer': organizerName, 'isFollowing': isFollowing,
        })));
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 左: 日付
            Container(
              width: 52, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(month, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                Text(day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
              ]),
            ),
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
                Flexible(child: Text(courts > 0 ? '$location（${courts}コート）' : location,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.sports_volleyball, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                Text([type, format].where((s) => s.toString().isNotEmpty).join(' ／ '),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (entryFee.toString().isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.payments, size: 13, color: AppTheme.textSecondary), const SizedBox(width: 4),
                  Text(entryFee.toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ]),
              const SizedBox(height: 8),
              // チーム数 + プログレスバー
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ),
          ]),
        ),
      ),
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
