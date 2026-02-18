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
  late TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  Set<String> _followingIds = {};
  Set<String> _enteredTournamentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFollowing();
    _loadEnteredTournaments();
  }

  Future<void> _loadFollowing() async {
    if (_currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('following')
        .get();
    setState(() {
      _followingIds = snap.docs.map((d) => d.id).toSet();
    });
  }

  Future<void> _loadEnteredTournaments() async {
    if (_currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('tournaments')
        .get();
    final entered = <String>{};
    for (final doc in snap.docs) {
      final entriesSnap = await doc.reference
          .collection('entries')
          .where('enteredBy', isEqualTo: _currentUser!.uid)
          .limit(1)
          .get();
      if (entriesSnap.docs.isNotEmpty) {
        entered.add(doc.id);
      }
    }
    if (mounted) {
      setState(() {
        _enteredTournamentIds = entered;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: '大会'),
            Tab(text: 'メンバー募集'),
            Tab(text: 'みつける'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTournamentList(followedOnly: true),
          _buildRecruitTab(),
          _buildTournamentList(followedOnly: false),
        ],
      ),
    );
  }

  // ━━━ 大会リスト（共通） ━━━
  Widget _buildTournamentList({required bool followedOnly}) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '大会名・会場名で検索',
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
        if (!followedOnly)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: AppTheme.textHint),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'フォローしていない主催者の大会です。エントリーにはフォローが必要です。',
                style: TextStyle(fontSize: 11, color: AppTheme.textHint),
              )),
            ]),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tournaments')
                .snapshots(),
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

                // フォロー中タブ: フォロー中の主催者の大会のみ
                // みつけるタブ: フォロー外の主催者で募集中 or 終了（結果閲覧）のみ
                if (followedOnly) {
                  if (!isFollowing) return false;
                  // 開催中・決勝中はエントリー済みのみ表示
                  if ((status == '開催中' || status == '決勝中') && !isEntered) return false;
                } else {
                  if (isFollowing) return false;
                  // みつけるタブ: 募集中 or 終了のみ
                  if (status != '募集中' && status != '終了') return false;
                }

                // テキスト検索
                if (query.isNotEmpty) {
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();
                  final type = (data['type'] ?? '').toString().toLowerCase();
                  return title.contains(query) || location.contains(query) || type.contains(query);
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        followedOnly ? Icons.emoji_events_outlined : Icons.explore_outlined,
                        size: 64, color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        followedOnly ? 'フォロー中の主催者の大会はありません' : '新しい大会が見つかりません',
                        style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        followedOnly
                            ? '主催者をフォローすると\nここに大会が表示されます'
                            : 'フォロー外の主催者の大会が\nここに表示されます',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTournamentCard(filtered[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

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
      case '締切間近': statusColor = AppTheme.warning; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = AppTheme.primaryColor; break;
      case '終了': statusColor = AppTheme.textSecondary; break;
      default: statusColor = AppTheme.textSecondary;
    }

    final progress = maxTeams > 0 ? currentTeams / maxTeams : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.03),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(organizerName, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                if (!isFollowing) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.textHint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('未フォロー', style: TextStyle(fontSize: 10, color: AppTheme.textHint)),
                  ),
                ],
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildInfoRow(Icons.calendar_today, date),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.location_on, courts > 0 ? '$location（${courts}コート）' : location),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.category, [type, format].where((s) => s.isNotEmpty).join(' ／ ')),
              if (entryFee.toString().isNotEmpty) ...[const SizedBox(height: 6), _buildInfoRow(Icons.payments, entryFee.toString())],
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.groups, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('$currentTeams / $maxTeams チーム',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppTheme.error : progress >= 0.8 ? AppTheme.warning : AppTheme.success),
                  minHeight: 6),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(tournament: {
                        'id': doc.id,
                        'name': title, 'date': date, 'venue': location,
                        'courts': courts, 'type': type, 'format': format,
                        'currentTeams': currentTeams, 'maxTeams': maxTeams,
                        'fee': entryFee, 'status': status, 'statusColor': statusColor,
                        'deadline': '', 'organizer': organizerName,
                        'isFollowing': isFollowing,
                      }),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? AppTheme.primaryColor : AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    status == '終了' ? '結果を見る' : (isFollowing ? '詳細を見る・エントリー' : '詳細を見る'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ━━━ メンバー募集タブ ━━━
  Widget _buildRecruitTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recruitments')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('メンバー募集はまだありません', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecruitCard(data),
            );
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
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 20,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                if (!isFollowing) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.textHint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text('未フォロー', style: TextStyle(fontSize: 10, color: AppTheme.textHint))),
                ],
              ]),
              if (experience.isNotEmpty)
                Text('競技歴 $experience', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ])),
          ]),
          if (tournamentName.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.04), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tournamentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                if (tournamentDate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tournamentDate, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ]),
            ),
          if (recruitCount > 0)
            Padding(padding: const EdgeInsets.only(top: 12),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('あと${recruitCount}人',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.error)))),
          if (comment.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 10),
                child: Text(comment, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5))),
          Padding(padding: const EdgeInsets.only(top: 12),
              child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isFollowing ? () {} : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? AppTheme.primaryColor : AppTheme.textSecondary.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text(isFollowing ? '応募する' : 'フォローすると応募できます',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: isFollowing ? Colors.white : AppTheme.textSecondary)),
                  ))),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: AppTheme.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
    ]);
  }
}
