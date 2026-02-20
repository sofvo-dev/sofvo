import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'score_input_screen.dart';
import 'checkin_screen.dart';
import '../../services/match_generator.dart';
import '../profile/user_profile_screen.dart';
import '../../services/pdf_generator.dart';
import 'package:printing/printing.dart';
import '../chat/chat_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  const TournamentDetailScreen({super.key, required this.tournament});
  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isEntryDeadlinePassed;
  late bool _isFollowing;
  final _firestore = FirebaseFirestore.instance;
  List<String> _myTeamIds = [];
  final _postController = TextEditingController();
  bool _isBoardTeam = false; // false=大会掲示板, true=チーム掲示板
  String _myEntryTeamId = "";

  String get _tournamentId => widget.tournament['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    final status = widget.tournament['status'] as String;
    _isEntryDeadlinePassed = status == '満員' || status == '開催済み' || status == '開催中' || status == '決勝中' || status == '終了' || status.contains('完了') || widget.tournament['organizerId'] == FirebaseAuth.instance.currentUser?.uid;
    _isFollowing = widget.tournament['isFollowing'] as bool? ?? true;
    _tabController = TabController(
      length: _isEntryDeadlinePassed ? 4 : 3,
      vsync: this,
    );
    _loadMyTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postController.dispose();
    super.dispose();
  }


  Future<void> _loadMyTeams() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || _tournamentId.isEmpty) return;
    final entries = await _firestore.collection('tournaments').doc(_tournamentId)
        .collection('entries').where('enteredBy', isEqualTo: uid).get();
    final teamIds = entries.docs.map((d) => d['teamId'] as String? ?? '').where((id) => id.isNotEmpty).toList();
    if (mounted) setState(() {
      _myTeamIds = teamIds;
      _myEntryTeamId = teamIds.isNotEmpty ? teamIds.first : "";
    });
  }
  // ── 大会チャットを開く or 作成 ──
  Future<void> _openOrCreateTournamentChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty || _tournamentId.isEmpty) return;

    // linkedId で大会に紐づくチャットを検索
    final existing = await _firestore
        .collection('chats')
        .where('type', isEqualTo: 'tournament')
        .where('linkedId', isEqualTo: _tournamentId)
        .get();

    String chatId;
    if (existing.docs.isNotEmpty) {
      chatId = existing.docs.first.id;
      // 自分がmembersに入っていなければ追加
      final members = List<String>.from(existing.docs.first['members'] ?? []);
      if (!members.contains(uid)) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final myName = (userDoc.data()?['nickname'] as String?) ?? 'ユーザー';
        await _firestore.collection('chats').doc(chatId).update({
          'members': FieldValue.arrayUnion([uid]),
          'memberNames.$uid': myName,
        });
      }
    } else {
      // 新規作成：自分だけで作成（他の参加者はチャットを開いた時に追加される）
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final myName = (userDoc.data()?['nickname'] as String?) ?? 'ユーザー';
      final tournamentName = widget.tournament['name'] as String? ?? '大会チャット';

      final ref = await _firestore.collection('chats').add({
        'type': 'tournament',
        'name': tournamentName,
        'linkedId': _tournamentId,
        'members': [uid],
        'memberNames': {uid: myName},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = ref.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            chatTitle: widget.tournament['name'] as String? ?? '大会チャット',
            chatType: 'tournament',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final status = (t['status'] ?? '準備中') as String;
    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '準備中': statusColor = AppTheme.warning; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      default: statusColor = AppTheme.textSecondary;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(t['name'] as String,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: _openOrCreateTournamentChat),
          IconButton(icon: const Icon(Icons.share), onPressed: () => _showShareSheet(context)),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(t, status, statusColor),
          if (!_isFollowing) _buildFollowBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                if (_isEntryDeadlinePassed) _buildMatchTableTab(),
                _buildTeamsTab(),
                _buildTimelineTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildHeader(Map<String, dynamic> t, String status, Color statusColor) {
    final currentTeams = t['currentTeams'] is int ? t['currentTeams'] as int : 0;
    final maxTeams = t['maxTeams'] is int ? t['maxTeams'] as int : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primaryColor, AppTheme.primaryLight],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
              child: Text(t['type'] as String, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(t['name'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(t['date'] as String, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(width: 16),
            const Icon(Icons.groups, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('$currentTeams/$maxTeams チーム', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(width: 16),
            const Icon(Icons.location_on, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(t['location'] as String? ?? t['venue'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildFollowBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.warning.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text('主催者をフォローするとエントリーできます', style: TextStyle(fontSize: 13, color: AppTheme.warning))),
          TextButton(
            onPressed: () {
              setState(() => _isFollowing = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('主催者をフォローしました！'), backgroundColor: AppTheme.success),
              );
            },
            child: const Text('フォローする', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          const Tab(text: '概要'),
          if (_isEntryDeadlinePassed) const Tab(text: '対戦表'),
          const Tab(text: 'チーム'),
          const Tab(text: '掲示板'),
        ],
      ),
    );
  }

  // ━━━ 概要タブ ━━━
  Widget _buildOverviewTab() {
    final t = widget.tournament;
    final currentTeams = t['currentTeams'] is int ? t['currentTeams'] as int : 0;
    final maxTeams = t['maxTeams'] is int ? t['maxTeams'] as int : 1;
    final progress = maxTeams > 0 ? currentTeams / maxTeams : 0.0;
    final rules = t['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
    final scoring = rules['scoring'] as Map<String, dynamic>? ?? {};
    final management = rules['management'] as Map<String, dynamic>? ?? {};
    final other = rules['other'] as Map<String, dynamic>? ?? {};
    final courts = t['courts'] ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).snapshots(),
      builder: (context, snap) {
        // Use live data if available
        Map<String, dynamic> live = {};
        if (snap.hasData && snap.data!.exists) {
          live = snap.data!.data() as Map<String, dynamic>? ?? {};
        }
        final liveCurrentTeams = live['currentTeams'] as int? ?? currentTeams;
        final liveMaxTeams = live['maxTeams'] as int? ?? maxTeams;
        final liveProgress = liveMaxTeams > 0 ? liveCurrentTeams / liveMaxTeams : 0.0;
        final liveStatus = live['status'] ?? t['status'] ?? '';
        final liveRules = live['rules'] as Map<String, dynamic>? ?? rules;
        final livePrelim = liveRules['preliminary'] as Map<String, dynamic>? ?? preliminary;
        final liveFinal = liveRules['final'] as Map<String, dynamic>? ?? finalRules;
        final liveScoring = liveRules['scoring'] as Map<String, dynamic>? ?? scoring;
        final liveManagement = liveRules['management'] as Map<String, dynamic>? ?? management;
        final liveOther = liveRules['other'] as Map<String, dynamic>? ?? other;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ━━━ Organizer ━━━
            GestureDetector(
              onTap: () {
                final organizerId = t['organizerId'] as String?;
                if (organizerId != null && organizerId.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: organizerId),
                  ));
                }
              },
              child: _buildCard(
                child: Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                      child: const Text('主', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['organizer'] as String? ?? t['organizerName'] as String? ?? '主催者',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.star, size: 14, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text('主催者', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.textHint),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ━━━ Basic Info ━━━
            _buildCard(
              title: '基本情報',
              titleIcon: Icons.info_outline,
              child: Column(children: [
                _buildInfoRow(Icons.calendar_today, '開催日', t['date'] as String? ?? ''),
                _buildDivider(),
                _buildInfoRow(Icons.location_on, '会場', t['location'] as String? ?? t['venue'] as String? ?? ''),
                if ((t['venueAddress'] ?? '').toString().isNotEmpty) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.map, '住所', t['venueAddress'] as String? ?? ''),
                ],
                _buildDivider(),
                _buildInfoRow(Icons.grid_view, 'コート数', '${courts}コート'),
                _buildDivider(),
                _buildInfoRow(Icons.category, '種別', '${t['format'] ?? '4人制'} / ${t['type'] ?? '混合'}'),
                _buildDivider(),
                _buildInfoRow(Icons.payments, '参加費', t['entryFee'] as String? ?? t['fee'] as String? ?? ''),
              ]),
            ),
            const SizedBox(height: 12),


            // ━━━ Schedule ━━━
            _buildCard(
              title: '当日スケジュール',
              titleIcon: Icons.schedule,
              child: Column(children: [
                _buildInfoRow(Icons.door_front_door, '開場', live['openTime'] as String? ?? t['openTime'] as String? ?? '8:00'),
                _buildDivider(),
                _buildInfoRow(Icons.how_to_reg, '受付', live['receptionTime'] as String? ?? t['receptionTime'] as String? ?? '8:30'),
                _buildDivider(),
                _buildInfoRow(Icons.groups, '開会式', live['openingTime'] as String? ?? t['openingTime'] as String? ?? '9:00'),
                _buildDivider(),
                _buildInfoRow(Icons.sports_volleyball, '試合開始', live['matchStartTime'] as String? ?? t['matchStartTime'] as String? ?? '9:15'),
                if ((t['lunchTime'] ?? '').toString().isNotEmpty) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.lunch_dining, '昼休憩', t['lunchTime'] as String? ?? ''),
                ],
                _buildDivider(),
                _buildInfoRow(Icons.emoji_events, '決勝予定', live['finalTime'] as String? ?? t['finalTime'] as String? ?? '14:00'),
                _buildDivider(),
                _buildInfoRow(Icons.celebration, '閉会式', live['closingTime'] as String? ?? t['closingTime'] as String? ?? '16:00'),
              ]),
            ),
            const SizedBox(height: 12),

            // ━━━ Entry status ━━━
            _buildCard(
              title: '募集状況',
              titleIcon: Icons.how_to_reg,
              child: Column(children: [
                Row(children: [
                  Icon(Icons.groups, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('$liveCurrentTeams / $liveMaxTeams チーム',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: liveProgress >= 1.0 ? AppTheme.error.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(liveProgress >= 1.0 ? '満員' : '残り${liveMaxTeams - liveCurrentTeams}枠',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: liveProgress >= 1.0 ? AppTheme.error : AppTheme.success)),
                  ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: liveProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      liveProgress >= 1.0 ? AppTheme.error : liveProgress >= 0.8 ? AppTheme.warning : AppTheme.success),
                    minHeight: 10,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ━━━ Rules Detail ━━━
            _buildCard(
              title: '大会ルール',
              titleIcon: Icons.gavel,
              child: Column(children: [
                _buildInfoRow(Icons.sports_volleyball, '試合形式', '${t['format'] ?? '4人制'}（15点先取）'),
                _buildDivider(),
                _buildInfoRow(Icons.repeat, '予選', '${livePrelim['sets'] ?? 2}セットマッチ'),
                _buildDivider(),
                _buildInfoRow(Icons.swap_vert, 'ジュース', (livePrelim['deuce'] ?? false) ? 'あり（${livePrelim['deuceCap'] ?? 17}点キャップ）' : 'なし'),
                if (liveScoring.isNotEmpty) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.emoji_events, '勝ち点制', 'あり'),
                  if (liveScoring['win20'] != null) ...[
                    _buildDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _buildPointRow('2-0 勝ち', liveScoring['win20']),
                        _buildPointRow('1-1 得失差勝ち', liveScoring['win11']),
                        _buildPointRow('1-1 引き分け', liveScoring['draw']),
                        _buildPointRow('1-1 得失差負け', liveScoring['lose11']),
                        _buildPointRow('0-2 負け', liveScoring['lose02']),
                      ]),
                    ),
                  ],
                ],
                if ((liveFinal['enabled'] ?? false) == true) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.emoji_events, '決勝', '${liveFinal['sets'] ?? 3}セットマッチ${(liveFinal['deuce'] ?? false) ? '（ジュースあり）' : ''}'),
                  if (liveFinal['thirdPlace'] == true) ...[
                    _buildDivider(),
                    _buildInfoRow(Icons.looks_3, '3位決定戦', 'あり'),
                  ],
                ],
              ]),
            ),
            const SizedBox(height: 12),

            // ━━━ Management info ━━━
            if (liveManagement.isNotEmpty) _buildCard(
              title: '運営情報',
              titleIcon: Icons.admin_panel_settings,
              child: Column(children: [
                if (liveManagement['teamsPerCourt'] != null)
                  _buildInfoRow(Icons.people, '1コートあたり', '${liveManagement['teamsPerCourt']}チーム'),
                if (liveManagement['teamsPerCourt'] != null && courts > 0) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.calculate, '最大収容', '${(liveManagement['teamsPerCourt'] as int? ?? 4) * courts}チーム'),
                ],
                if (livePrelim['rounds'] != null) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.loop, '予選ラウンド数', '${livePrelim['rounds']}回'),
                ],
              ]),
            ),
            if (liveManagement.isNotEmpty) const SizedBox(height: 12),

            // ━━━ Other settings ━━━
            if (liveOther.isNotEmpty) _buildCard(
              title: 'その他',
              titleIcon: Icons.more_horiz,
              child: Column(children: [
                if (liveOther['uniformNumber'] != null)
                  _buildInfoRow(Icons.format_list_numbered, 'ゼッケン', liveOther['uniformNumber'] == true ? '必須' : '不要'),
                if (liveOther['snsVideo'] != null) ...[
                  _buildDivider(),
                  _buildInfoRow(Icons.videocam, 'SNS動画投稿', liveOther['snsVideo'] == true ? '許可' : '不可'),
                ],
              ]),
            ),
            if (liveOther.isNotEmpty) const SizedBox(height: 12),

            // ━━━ Tournament flow ━━━
            _buildCard(
              title: '大会の流れ',
              titleIcon: Icons.timeline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildFlowStep(1, 'エントリー受付', liveStatus == '募集中', liveCurrentTeams > 0),
                _buildFlowStep(2, '予選リーグ（ラウンドロビン）', liveStatus == '開催中', false),
                if ((livePrelim['rounds'] ?? 1) > 1)
                  _buildFlowStep(3, '予選2（ランク別再編成）', false, false),
                _buildFlowStep((livePrelim['rounds'] ?? 1) > 1 ? 4 : 3, '決勝トーナメント', liveStatus == '決勝中', false),
                _buildFlowStep((livePrelim['rounds'] ?? 1) > 1 ? 5 : 4, '結果発表・表彰', liveStatus == '終了', false, isLast: true),
              ]),
            ),

            // ━━━ 結果（終了時のみ） ━━━
            if (liveStatus == '終了')
              _buildCard(
                title: '大会結果',
                titleIcon: Icons.emoji_events,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('tournaments').doc(_tournamentId)
                      .collection('brackets').snapshots(),
                  builder: (context, bracketSnap) {
                    if (!bracketSnap.hasData || bracketSnap.data!.docs.isEmpty) {
                      return const Text('決勝データがまだありません', style: TextStyle(color: AppTheme.textSecondary));
                    }
                    return Column(
                      children: bracketSnap.data!.docs.map((bDoc) {
                        return StreamBuilder<QuerySnapshot>(
                          stream: bDoc.reference.collection('matches')
                              .where('status', isEqualTo: 'completed').snapshots(),
                          builder: (context, mSnap) {
                            if (!mSnap.hasData) return const SizedBox();
                            final matches = mSnap.data!.docs;
                            final finalMatch = matches.where((m) =>
                              (m.data() as Map<String, dynamic>)['round'] == 'final').firstOrNull;
                            if (finalMatch == null) return const Text('決勝が完了していません');
                            final fm = finalMatch.data() as Map<String, dynamic>;
                            final result = fm['result'] as Map<String, dynamic>? ?? {};
                            final winnerId = result['winner'] ?? '';
                            final champion = winnerId == fm['teamAId'] ? fm['teamAName'] : fm['teamBName'];
                            final runnerUp = winnerId == fm['teamAId'] ? fm['teamBName'] : fm['teamAName'];

                            return Column(children: [
                              _buildResultRow(Icons.military_tech, '優勝', champion ?? '', Colors.amber),
                              const SizedBox(height: 8),
                              _buildResultRow(Icons.star, '準優勝', runnerUp ?? '', AppTheme.primaryColor),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _shareResult(champion ?? '', runnerUp ?? ''),
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('結果をシェア'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                            ]);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  void _shareResult(String champion, String runnerUp) {
    final t = widget.tournament;
    final text = '${t['name']}\n\n'
        '優勝: $champion\n'
        '準優勝: $runnerUp\n\n'
        '日程: ${t['date']}\n'
        '会場: ${t['location'] ?? t['venue'] ?? ''}\n\n'
        '#Sofvo #バレーボール大会';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('結果をコピーしました！SNSに貼り付けてシェアしましょう'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String team, Color color) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        Text(team, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ]),
    ]);
  }

  

  Widget _buildPointRow(String label, dynamic points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        const SizedBox(width: 8),
        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Text('${points ?? 0}点', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ]),
    );
  }

  Widget _buildFlowStep(int step, String label, bool isCurrent, bool isCompleted, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(children: [
        Column(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.success : isCurrent ? AppTheme.primaryColor : Colors.grey[200],
              shape: BoxShape.circle,
              boxShadow: isCurrent ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 6)] : [],
            ),
            child: Center(child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$step', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : AppTheme.textSecondary))),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2, color: isCompleted ? AppTheme.success.withValues(alpha: 0.3) : Colors.grey[200])),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(label, style: TextStyle(fontSize: 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? AppTheme.primaryColor : isCompleted ? AppTheme.success : AppTheme.textPrimary)),
          ),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('進行中', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Widget _buildMatchTableTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).snapshots(),
      builder: (context, tournSnap) {
        if (!tournSnap.hasData) return const Center(child: CircularProgressIndicator());
        final tournData = tournSnap.data!.data() as Map<String, dynamic>? ?? {};
        final isOrganizer = tournData['organizerId'] == uid;
        final status = tournData['status'] ?? '準備中';

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('tournaments').doc(_tournamentId).collection('rounds').snapshots(),
          builder: (context, roundsSnap) {
            final hasRounds = roundsSnap.hasData && roundsSnap.data!.docs.isNotEmpty;

            if (!hasRounds) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.grid_on, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text(status == '募集中' ? '対戦表はエントリー締切後に生成されます' : '対戦表を生成してください',
                      style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary), textAlign: TextAlign.center),
                  if (isOrganizer) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _generateMatches(1),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('対戦表を自動生成', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ]),
              ));
            }

            // Show rounds and matches
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Organizer actions
                if (isOrganizer) _buildOrganizerActions(tournData),

                // Show each round
                ...roundsSnap.data!.docs.map((roundDoc) {
                  final roundData = roundDoc.data() as Map<String, dynamic>;
                  final roundNum = roundData['roundNumber'] ?? 1;
                  return _buildRoundSection(roundDoc.id, roundNum, isOrganizer);
                }),

                // Show brackets if exist
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('tournaments').doc(_tournamentId).collection('brackets').snapshots(),
                  builder: (context, bracketSnap) {
                    if (!bracketSnap.hasData || bracketSnap.data!.docs.isEmpty) return const SizedBox();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 16),
                      ...bracketSnap.data!.docs.map((bDoc) {
                        final bData = bDoc.data() as Map<String, dynamic>;
                        return _buildBracketSection(bDoc.id, bData, isOrganizer);
                      }),
                    ]);
                  },
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganizerActions(Map<String, dynamic> tournData) {
    final rules = tournData['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final prelimRounds = preliminary['rounds'] ?? 1;
    final finalEnabled = (rules['final'] as Map<String, dynamic>?)?['enabled'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('主催者メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _actionChip('受付管理', Icons.qr_code_scanner, () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')))),
          _actionChip('テストチーム追加', Icons.group_add, _addTestTeams),
          if (prelimRounds >= 2)
            _actionChip('予選2 生成', Icons.replay, () => _generateMatches(2)),
          if (finalEnabled)
            _actionChip('決勝生成', Icons.emoji_events, _generateFinals),
          _actionChip('リセット', Icons.refresh, _resetRounds),
        ]),
        if (tournData['status'] == '開催中' || tournData['status'] == '決勝中') ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEndTournamentDialog(),
              icon: const Icon(Icons.flag, size: 18),
              label: const Text('大会を終了する', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  void _showMyTeamQR(String teamId, String teamName) {
    final qrData = 'sofvo://checkin/$_tournamentId/$teamId';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(teamName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('このQRを受付スタッフに見せてください',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          QrImageView(data: qrData, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ]),
      ),
    );
  }

  void _showEndTournamentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('大会を終了する', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('大会を終了しますか？\nステータスが「終了」に変わり、結果が表示されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('tournaments').doc(_tournamentId).update({'status': '終了'});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('大会を終了しました'), backgroundColor: AppTheme.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('終了する'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSection(String roundId, int roundNum, bool isOrganizer) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('予選$roundNum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tournaments').doc(_tournamentId)
            .collection('rounds').doc(roundId)
            .collection('matches').orderBy('matchOrder').snapshots(),
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) return const Center(child: CircularProgressIndicator());
          final matches = matchSnap.data!.docs;
          if (matches.isEmpty) return const Text('試合がありません');

          // Group by court
          final courtGroups = <String, List<QueryDocumentSnapshot>>{};
          for (var m in matches) {
            final courtId = (m.data() as Map<String, dynamic>)['courtId'] ?? '';
            courtGroups.putIfAbsent(courtId, () => []);
            courtGroups[courtId]!.add(m);
          }

          final sortedCourts = courtGroups.entries.toList()..sort((a, b) {
            final aNum = (a.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            final bNum = (b.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            return (aNum as int).compareTo(bNum as int);
          });
          return Column(children: sortedCourts.map((court) {
            final courtNum = (court.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            return _buildCourtCard(court.key, courtNum, court.value, roundId, isOrganizer);
          }).toList());
        },
      ),
      // Standings
      StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tournaments').doc(_tournamentId)
            .collection('rounds').doc(roundId)
            .collection('standings').snapshots(),
        builder: (context, standSnap) {
          if (!standSnap.hasData || standSnap.data!.docs.isEmpty) return const SizedBox();
          return Column(children: standSnap.data!.docs.map((courtDoc) {
            final courtData = courtDoc.data() as Map<String, dynamic>;
            return _buildStandingsCard(courtDoc.id, courtData['courtNumber'] ?? 0, roundId);
          }).toList());
        },
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildCourtCard(String courtId, int courtNum, List<QueryDocumentSnapshot> matches, String roundId, bool isOrganizer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Icon(Icons.sports_volleyball, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${String.fromCharCode(64 + courtNum)}コート', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${matches.length}試合', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        ...matches.map((mDoc) {
          final m = mDoc.data() as Map<String, dynamic>;
          final status = m['status'] ?? 'pending';
          final sets = (m['sets'] as List<dynamic>?) ?? [];
          final result = m['result'] as Map<String, dynamic>? ?? {};
          final matchOrder = m['matchOrder'] ?? 0;

          final matchOrd = m['matchOrder'] ?? 1;
          final prevMatch = matchOrd > 1 ? matches.where((prev) {
            final pd = prev.data() as Map<String, dynamic>;
            return (pd['matchOrder'] ?? 0) == matchOrd - 1;
          }).firstOrNull : null;
          final prevDone = matchOrd <= 1 || (prevMatch != null && (prevMatch.data() as Map<String, dynamic>)['status'] == 'completed');
          final isReferee = _myTeamIds.contains(m['refereeTeamId'] ?? '') || _myTeamIds.contains(m['subRefereeTeamId'] ?? '');
          final canInput = isOrganizer || isReferee;
          return InkWell(
            onTap: canInput
              ? (prevDone ? () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreInputScreen(
                    tournamentId: _tournamentId, matchId: mDoc.id, roundId: roundId)));
                } : () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("前の試合が完了してから入力してください"), backgroundColor: Colors.orange)); })
              : null,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 8, bottom: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("第$matchOrder試合", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  Row(children: [
                    Text("主審: ", style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                    Text(m['refereeTeamName'] ?? '未定', style: TextStyle(fontSize: 13, color: _myTeamIds.contains(m['refereeTeamId'] ?? '') ? Colors.red : AppTheme.textHint, fontWeight: _myTeamIds.contains(m['refereeTeamId'] ?? '') ? FontWeight.bold : FontWeight.normal)),
                    Text(" / 副審: ", style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                    Text(m['subRefereeTeamName'] ?? 'ー', style: TextStyle(fontSize: 13, color: _myTeamIds.contains(m['subRefereeTeamId'] ?? '') ? Colors.red : AppTheme.textHint, fontWeight: _myTeamIds.contains(m['subRefereeTeamId'] ?? '') ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: Container(
                    child: Text(m['teamAName'] ?? '', style: TextStyle(fontSize: 16,
                      color: _myTeamIds.contains(m['teamAId'] ?? '') ? Colors.red : null,
                      fontWeight: _myTeamIds.contains(m['teamAId'] ?? '') || (status == 'completed' && result['winner'] == m['teamAId']) ? FontWeight.bold : FontWeight.normal),
                      textAlign: TextAlign.right))),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'completed' ? AppTheme.success.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      status == 'completed' ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}' : 'vs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: status == 'completed' ? AppTheme.success : AppTheme.textSecondary)),
                  ),
                  Expanded(flex: 3, child: Container(
                    child: Text(m['teamBName'] ?? '', style: TextStyle(fontSize: 16,
                      color: _myTeamIds.contains(m['teamBId'] ?? '') ? Colors.red : null,
                      fontWeight: _myTeamIds.contains(m['teamBId'] ?? '') || (status == 'completed' && result['winner'] == m['teamBId']) ? FontWeight.bold : FontWeight.normal)))),
                  if (status == 'completed')
                    const Icon(Icons.check_circle, size: 16, color: AppTheme.success)
                  else
                    Icon(Icons.play_circle_outline, size: 16, color: AppTheme.textHint),
                ]),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[300]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildStandingsCard(String courtId, int courtNum, String roundId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId)
          .collection('rounds').doc(roundId)
          .collection('standings').doc(courtId)
          .collection('teams').orderBy('matchPoints', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final teams = snap.data!.docs;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
              child: Row(children: [
                const Icon(Icons.leaderboard, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Text('${String.fromCharCode(64 + courtNum)}コート 順位表', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: const [
                SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                Expanded(flex: 3, child: Text('チーム', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
                SizedBox(width: 40, child: Text('勝点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text('得失', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
                SizedBox(width: 40, child: Text('総得', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
              ]),
            ),
            Divider(height: 1, color: Colors.grey[200]),
            ...teams.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value.data() as Map<String, dynamic>;
              final isMyTeam = _myTeamIds.contains(t['teamId'] ?? '');
              return Container(
                color: isMyTeam ? Colors.red.withOpacity(0.08) : null,
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: i == 0 ? Colors.amber : AppTheme.textPrimary))),
                  Expanded(flex: 3, child: Text(t['teamName'] ?? '', style: TextStyle(fontSize: 15, color: _myTeamIds.contains(t['teamId'] ?? '') ? Colors.red : null, fontWeight: _myTeamIds.contains(t['teamId'] ?? '') ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 40, child: Text('${t['matchPoints'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('${t['pointDiff'] ?? 0}', style: TextStyle(fontSize: 13, color: (t['pointDiff'] ?? 0) >= 0 ? AppTheme.success : AppTheme.error), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('${t['totalPoints'] ?? 0}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                ]),
              ),
              );
            }),
          ]),
        );
      },
    );
  }

  Widget _buildBracketSection(String bracketId, Map<String, dynamic> bData, bool isOrganizer) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
          const SizedBox(width: 8),
          Text('${bData['bracketName'] ?? '決勝'}トーナメント',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tournaments').doc(_tournamentId)
            .collection('brackets').doc(bracketId)
            .collection('matches').orderBy('matchNumber').snapshots(),
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) return const SizedBox();
          return Column(children: matchSnap.data!.docs.map((mDoc) {
            final m = mDoc.data() as Map<String, dynamic>;
            final status = m['status'] ?? 'pending';
            final result = m['result'] as Map<String, dynamic>? ?? {};
            final roundLabel = m['round'] == 'semi' ? '準決勝' : (m['round'] == 'final' ? '決勝' : (m['round'] == '3rd' ? '3位決定戦' : ''));

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.3))),
              child: InkWell(
                onTap: (isOrganizer && status != 'waiting') ? () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreInputScreen(
                    tournamentId: _tournamentId, matchId: mDoc.id, roundId: '', isBracket: true, bracketId: bracketId)));
                } : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (roundLabel.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 6),
                        child: Text(roundLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[800]))),
                    Row(children: [
                      Expanded(flex: 3, child: Text(m['teamAName'] ?? '', style: TextStyle(fontSize: 16,
                          fontWeight: status == 'completed' && result['winner'] == m['teamAId'] ? FontWeight.bold : FontWeight.normal),
                          textAlign: TextAlign.right)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'completed' ? Colors.amber.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          status == 'completed' ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}' : (status == 'waiting' ? '待機中' : 'vs'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: status == 'completed' ? Colors.amber[800] : AppTheme.textSecondary)),
                      ),
                      Expanded(flex: 3, child: Text(m['teamBName'] ?? '', style: TextStyle(fontSize: 16,
                          fontWeight: status == 'completed' && result['winner'] == m['teamBId'] ? FontWeight.bold : FontWeight.normal))),
                    ]),
                  ]),
                ),
              ),
            );
          }).toList());
        },
      ),
    ]);
  }

  Future<void> _generateMatches(int roundNumber) async {
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      await MatchGenerator().generatePreliminary(tournamentId: _tournamentId, roundNumber: roundNumber);
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('予選$roundNumber の対戦表を生成しました！'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error));
      }
    }
  }



  Future<void> _resetRounds() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('対戦表をリセット'),
      content: const Text('全ての対戦表・スコア・順位表を削除します。\nこの操作は取り消せません。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('リセット')),
      ],
    ));
    if (confirm != true) return;
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      // Delete rounds
      final rounds = await _firestore.collection('tournaments').doc(_tournamentId).collection('rounds').get();
      for (var round in rounds.docs) {
        final matches = await round.reference.collection('matches').get();
        for (var m in matches.docs) { await m.reference.delete(); }
        final standings = await round.reference.collection('standings').get();
        for (var s in standings.docs) {
          final teams = await s.reference.collection('teams').get();
          for (var t in teams.docs) { await t.reference.delete(); }
          await s.reference.delete();
        }
        await round.reference.delete();
      }
      // Delete brackets
      final brackets = await _firestore.collection('tournaments').doc(_tournamentId).collection('brackets').get();
      for (var b in brackets.docs) {
        final matches = await b.reference.collection('matches').get();
        for (var m in matches.docs) { await m.reference.delete(); }
        await b.reference.delete();
      }
      await _firestore.collection('tournaments').doc(_tournamentId).update({'status': '募集中'});
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対戦表をリセットしました'), backgroundColor: AppTheme.success)); }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error)); }
    }
  }
  Future<void> _addTestTeams() async {
    final testTeams = [
      {'teamId': 'test_team_2', 'teamName': 'サンダーズ'},
      {'teamId': 'test_team_3', 'teamName': 'ファイヤーズ'},
      {'teamId': 'test_team_4', 'teamName': 'ストームズ'},
      {'teamId': 'test_team_5', 'teamName': 'ブレイカーズ'},
      {'teamId': 'test_team_6', 'teamName': 'ウィングス'},
      {'teamId': 'test_team_7', 'teamName': 'スパイカーズ'},
    ];
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      for (var team in testTeams) {
        final existing = await _firestore.collection('tournaments').doc(_tournamentId)
            .collection('entries').where('teamId', isEqualTo: team['teamId']).get();
        if (existing.docs.isEmpty) {
          await _firestore.collection('tournaments').doc(_tournamentId).collection('entries').add({
            'teamId': team['teamId'], 'teamName': team['teamName'],
            'leaderName': 'テスト', 'memberCount': 4,
            'memberNames': {'p1': '選手1', 'p2': '選手2', 'p3': '選手3', 'p4': '選手4'},
            'enteredBy': 'test', 'createdAt': FieldValue.serverTimestamp(),
          });
          await _firestore.collection('tournaments').doc(_tournamentId).update({'currentTeams': FieldValue.increment(1)});
        }
      }
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('テストチーム6チーム追加しました'), backgroundColor: AppTheme.success)); }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error)); }
    }
  }

  Future<void> _generateFinals() async {
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      await MatchGenerator().generateFinals(tournamentId: _tournamentId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('決勝トーナメントを生成しました！'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
  Widget _buildTeamsTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).collection('entries').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final entries = snapshot.data?.docs ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.groups_outlined, size: 64, color: AppTheme.textHint),
              const SizedBox(height: 16),
              const Text('まだエントリーはありません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
            ]),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('エントリー済み ${entries.length}チーム',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ...entries.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final teamName = data['teamName'] ?? 'チーム';
              final leader = data['leaderName'] ?? '';
              final memberUids = (data['memberUids'] as List<dynamic>?) ?? [];
              final isMyTeam = _myTeamIds.contains(data['teamId'] ?? '');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    final enteredBy = data['enteredBy'] as String?;
                    if (enteredBy != null && enteredBy.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: enteredBy),
                      ));
                    }
                  },
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMyTeam ? Colors.red.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMyTeam ? Colors.red.withOpacity(0.3) : Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: isMyTeam ? Colors.red.withOpacity(0.12) : AppTheme.primaryColor.withOpacity(0.12),
                        child: Text(teamName.toString().isNotEmpty ? teamName.toString()[0] : '?',
                            style: TextStyle(color: isMyTeam ? Colors.red : AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(teamName.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isMyTeam ? Colors.red : AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('キャプテン: $leader / ${memberUids.length}人', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    if (isMyTeam) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('自分', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showMyTeamQR(data['teamId'] ?? '', teamName.toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.qr_code, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text('QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildTimelineTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // 大会掲示板 / チーム掲示板 切り替え
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _isBoardTeam = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isBoardTeam ? AppTheme.primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('大会掲示板', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: !_isBoardTeam ? Colors.white : AppTheme.textSecondary))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () {
                if (_myEntryTeamId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('エントリーすると使えます'), backgroundColor: AppTheme.warning));
                  return;
                }
                setState(() => _isBoardTeam = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isBoardTeam ? AppTheme.primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('チーム掲示板', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _isBoardTeam ? Colors.white : AppTheme.textSecondary))),
              ),
            )),
          ]),
        ),

        // 投稿入力
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, size: 20, color: AppTheme.primaryColor)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _postController,
                  decoration: InputDecoration(
                    hintText: _isBoardTeam ? 'チームへメッセージ...' : 'コメントを投稿...',
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                    filled: true, fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _submitTimelinePost(uid)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),

        // 投稿一覧
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _isBoardTeam
                ? _firestore.collection('tournaments').doc(_tournamentId)
                    .collection('team_board').doc(_myEntryTeamId).collection('posts')
                    .orderBy('createdAt', descending: true).snapshots()
                : _firestore.collection('tournaments').doc(_tournamentId)
                    .collection('timeline').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final rawPosts = snapshot.data?.docs ?? [];
              final posts = List<QueryDocumentSnapshot>.from(rawPosts);
              if (!_isBoardTeam) {
                posts.sort((a, b) {
                  final aPin = (a.data() as Map<String, dynamic>)['pinned'] == true ? 0 : 1;
                  final bPin = (b.data() as Map<String, dynamic>)['pinned'] == true ? 0 : 1;
                  return aPin.compareTo(bPin);
                });
              }
              final isCurrentUserOrganizer = widget.tournament['organizerId'] == uid;

              if (posts.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isBoardTeam ? Icons.group : Icons.chat_bubble_outline, size: 48, color: AppTheme.textHint),
                    const SizedBox(height: 12),
                    Text(_isBoardTeam ? 'チーム掲示板にメッセージを投稿しよう！' : '最初のコメントを投稿しよう！',
                        style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                  ],
                ));
              }

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final postId = post.id;
                  final data = post.data() as Map<String, dynamic>;
                  final authorName = data['authorName'];
                  final authorAvatar = data['authorAvatar'];
                  final text = data['text'];
                  final isOrganizer = data['isOrganizer'] == true;
                  final isPinned = data['pinned'] == true;
                  final createdAt = data['createdAt'] as Timestamp?;
                  final likes = data['likesCount'] ?? 0;

                  String timeAgo = '';
                  if (createdAt != null) {
                    final diff = DateTime.now().difference(createdAt.toDate());
                    if (diff.inMinutes < 1) timeAgo = 'たった今';
                    else if (diff.inHours < 1) timeAgo = '${diff.inMinutes}分前';
                    else if (diff.inDays < 1) timeAgo = '${diff.inHours}時間前';
                    else timeAgo = '${diff.inDays}日前';
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.push_pin, size: 14, color: AppTheme.accentColor),
                              const SizedBox(width: 4),
                              Text('ピン留め', style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        Row(children: [
                          authorAvatar.toString().isNotEmpty
                              ? CircleAvatar(radius: 16, backgroundImage: NetworkImage(authorAvatar.toString()),
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12))
                              : CircleAvatar(radius: 16,
                                  backgroundColor: isOrganizer ? AppTheme.accentColor.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.12),
                                  child: Text(authorName.toString().isNotEmpty ? authorName.toString()[0] : '?',
                                      style: TextStyle(color: isOrganizer ? AppTheme.accentColor : AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13))),
                          const SizedBox(width: 8),
                          Text(authorName.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          if (isOrganizer) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text('主催者', style: TextStyle(fontSize: 10, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          const Spacer(),
                          Text(timeAgo, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                        ]),
                        const SizedBox(height: 8),
                        Text(text.toString(), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
                        const SizedBox(height: 8),
                        Row(children: [
                          if (!_isBoardTeam) ...[
                            GestureDetector(
                              onTap: () => _toggleTimelineLike(postId, uid),
                              child: Row(children: [
                                StreamBuilder<DocumentSnapshot>(
                                  stream: _firestore.collection('tournaments').doc(_tournamentId)
                                      .collection('timeline').doc(postId).collection('likes').doc(uid).snapshots(),
                                  builder: (context, likeSnap) {
                                    final liked = likeSnap.data?.exists == true;
                                    return Icon(liked ? Icons.favorite : Icons.favorite_border, size: 18,
                                        color: liked ? Colors.red : AppTheme.textHint);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Text('$likes', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ]),
                            ),
                            if (isCurrentUserOrganizer) ...[const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => _firestore.collection('tournaments').doc(_tournamentId)
                                    .collection('timeline').doc(postId).update({'pinned': !(isPinned)}),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.push_pin, size: 16, color: isPinned ? AppTheme.accentColor : AppTheme.textHint),
                                  const SizedBox(width: 4),
                                  Text(isPinned ? 'ピン解除' : 'ピン留め', style: TextStyle(fontSize: 12, color: isPinned ? AppTheme.accentColor : AppTheme.textSecondary)),
                                ]),
                              ),
                            ],
                          ],
                        ]),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _submitTimelinePost(String uid) async {
    final text = _postController.text.trim();
    if (text.isEmpty || _tournamentId.isEmpty) return;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final nickname = userData['nickname'] ?? '匿名';
    final avatar = userData['avatarUrl'] ?? '';

    if (_isBoardTeam && _myEntryTeamId.isNotEmpty) {
      // チーム掲示板に投稿
      await _firestore.collection('tournaments').doc(_tournamentId)
          .collection('team_board').doc(_myEntryTeamId).collection('posts').add({
        'authorId': uid, 'authorName': nickname, 'authorAvatar': avatar,
        'text': text, 'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 大会掲示板に投稿
      final tournamentDoc = await _firestore.collection('tournaments').doc(_tournamentId).get();
      final tournamentData = tournamentDoc.data() ?? {};
      final isOrganizer = tournamentData['organizerId'] == uid;

      await _firestore.collection('tournaments').doc(_tournamentId).collection('timeline').add({
        'authorId': uid, 'authorName': nickname, 'authorAvatar': avatar,
        'text': text, 'isOrganizer': isOrganizer, 'pinned': false,
        'likesCount': 0, 'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _postController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _toggleTimelineLike(String postId, String uid) async {
    if (uid.isEmpty || _tournamentId.isEmpty) return;
    final likeRef = _firestore.collection('tournaments').doc(_tournamentId)
        .collection('timeline').doc(postId).collection('likes').doc(uid);
    final postRef = _firestore.collection('tournaments').doc(_tournamentId)
        .collection('timeline').doc(postId);

    final likeDoc = await likeRef.get();
    if (likeDoc.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
      await postRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  String _formatTimeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${ts.toDate().month}/${ts.toDate().day}';
  }

  // ━━━ エントリーシート ━━━
  void _showEntrySheet(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final teamNameCtrl = TextEditingController();
    final selectedMembers = <String, String>{};  // uid -> nickname

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    const Text('大会にエントリー', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.tournament['name'] as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        Text(widget.tournament['date'] as String,
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // チーム名入力
                    const Text('エントリーチーム名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: teamNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'チーム名を入力',
                        filled: true,
                        fillColor: AppTheme.backgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // メンバー選択（フォロワーから）
                    const Text('メンバーを選択（フォロワーから）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('users').doc(uid)
                          .collection('following').snapshots(),
                      builder: (context, followSnap) {
                        if (!followSnap.hasData) return const Center(child: CircularProgressIndicator());
                        final followings = followSnap.data!.docs;
                        if (followings.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Text('フォロー中のユーザーがいません', style: TextStyle(color: AppTheme.textHint))),
                          );
                        }
                        return Container(
                          constraints: const BoxConstraints(maxHeight: 250),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: followings.length,
                            itemBuilder: (context, index) {
                              final fDoc = followings[index];
                              final fData = fDoc.data() as Map<String, dynamic>;
                              final fUid = fDoc.id;
                              final fName = fData['nickname'] ?? fData['userName'] ?? '名前なし';
                              final fAvatar = fData['avatarUrl'] ?? '';
                              final isSelected = selectedMembers.containsKey(fUid);

                              return ListTile(
                                leading: fAvatar.toString().isNotEmpty
                                    ? CircleAvatar(backgroundImage: NetworkImage(fAvatar.toString()), radius: 18)
                                    : CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                        child: Text(fName.toString()[0], style: TextStyle(color: AppTheme.primaryColor))),
                                title: Text(fName.toString(), style: const TextStyle(fontSize: 14)),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                                    : Icon(Icons.circle_outlined, color: Colors.grey[400]),
                                onTap: () {
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedMembers.remove(fUid);
                                    } else {
                                      selectedMembers[fUid] = fName.toString();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (selectedMembers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${selectedMembers.length}人選択中', style: TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 24),

                    // エントリーボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final teamName = teamNameCtrl.text.trim();
                          if (teamName.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('チーム名を入力してください'), backgroundColor: AppTheme.warning));
                            return;
                          }
                          _confirmNewEntry(sheetContext, teamName, selectedMembers);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('エントリーする', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmNewEntry(BuildContext sheetContext, String teamName, Map<String, String> members) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('エントリー確認', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「$teamName」で以下の大会にエントリーしますか？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.tournament['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.tournament['date'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ]),
            ),
            if (members.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('メンバー: ${members.values.join(", ")}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('エントリーする', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 同名チーム重複チェック
    final existing = await _firestore
        .collection('tournaments').doc(_tournamentId)
        .collection('entries').where('enteredBy', isEqualTo: uid).get();

    if (existing.docs.isNotEmpty) {
      Navigator.pop(sheetContext);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('既にエントリー済みです'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    // ユーザー名取得
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final leaderName = userDoc.data()?['nickname'] ?? '名前なし';

    // エントリー保存
    final entryId = _firestore.collection('tournaments').doc(_tournamentId).collection('entries').doc().id;
    await _firestore.collection('tournaments').doc(_tournamentId).collection('entries').doc(entryId).set({
      'teamId': entryId,
      'teamName': teamName,
      'leaderUid': uid,
      'leaderName': leaderName,
      'memberUids': [uid, ...members.keys],
      'memberNames': {uid: leaderName, ...members},
      'enteredBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // currentTeams更新
    await _firestore.collection('tournaments').doc(_tournamentId).update({
      'currentTeams': FieldValue.increment(1),
    });

    // 掲示板に自動投稿
    await _firestore.collection('tournaments').doc(_tournamentId).collection('timeline').add({
      'authorId': 'system',
      'authorName': 'システム',
      'authorAvatar': '',
      'text': '$teamNameがエントリーしました！',
      'isOrganizer': false,
      'pinned': false,
      'likesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(sheetContext);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エントリーが完了しました！'), backgroundColor: AppTheme.success),
      );
      setState(() {});
    }
  }
  // ━━━ 下部ボタン ━━━
  Widget _buildBottomButtons() {
    final status = widget.tournament['status'] as String;
    final isDisabled = status == '満員' || status == '開催済み' || status == '開催中' || status == '決勝中' || status == '終了' || status.contains('完了');

    if (isDisabled) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: _isFollowing
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isDisabled ? null : () => _showRecruitSheet(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('メンバー募集する', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDisabled ? null : () => _showEntrySheet(context),
                    icon: const Icon(Icons.how_to_reg, size: 18),
                    label: Text(
                      isDisabled ? (status == '満員' ? '満員です' : '開催済み') : 'エントリー',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isFollowing = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('主催者をフォローしました！エントリーできます'), backgroundColor: AppTheme.success),
                  );
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('フォローしてエントリー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
    );
  }

  // ━━━ メンバー募集シート ━━━
  void _showRecruitSheet(BuildContext context) {
    int recruitCount = 1;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    const Text('メンバー募集する', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.tournament['name'] as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        Text(widget.tournament['date'] as String,
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    const Text('募集人数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(4, (i) {
                        final count = i + 1;
                        final isSelected = recruitCount == count;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setModalState(() => recruitCount = count),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
                              ),
                              child: Text('${count}人', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppTheme.textPrimary)),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('コメント', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController, maxLines: 3, maxLength: 200,
                      decoration: InputDecoration(
                        hintText: '例: 一緒に楽しみましょう！初心者歓迎です',
                        hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                        filled: true, fillColor: AppTheme.backgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          final userDoc = await _firestore.collection('users').doc(uid).get();
                          final userData = userDoc.data() ?? {};
                          await _firestore.collection('recruitments').add({
                            'tournamentId': _tournamentId,
                            'tournamentName': widget.tournament['name'],
                            'tournamentDate': widget.tournament['date'],
                            'userId': uid,
                            'nickname': userData['nickname'] ?? '',
                            'avatarUrl': userData['avatarUrl'] ?? '',
                            'experience': userData['experience'] ?? '',
                            'recruitCount': recruitCount,
                            'comment': commentController.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('募集を投稿しました！'), backgroundColor: AppTheme.success),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('募集を投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ━━━ シェアシート ━━━
  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('PDF\u30c0\u30a6\u30f3\u30ed\u30fc\u30c9', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.description, color: AppTheme.primaryColor),
              title: const Text('\u5927\u4f1a\u8981\u9805PDF'),
              subtitle: const Text('\u57fa\u672c\u60c5\u5831\u30fb\u30eb\u30fc\u30eb\u30fb\u30b9\u30b1\u30b8\u30e5\u30fc\u30eb'),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF\u3092\u751f\u6210\u4e2d...')));
                final bytes = await PdfGenerator().generateTournamentSummary(_tournamentId);
                await PdfGenerator.sharePdf(bytes, '${widget.tournament['name']}_\u8981\u9805');
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: AppTheme.success),
              title: const Text('\u5bfe\u6226\u8868PDF'),
              subtitle: const Text('\u30b3\u30fc\u30c8\u5225\u8a66\u5408\u4e00\u89a7\u30fb\u9806\u4f4d\u8868'),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF\u3092\u751f\u6210\u4e2d...')));
                final bytes = await PdfGenerator().generateMatchTable(_tournamentId);
                await PdfGenerator.sharePdf(bytes, '${widget.tournament['name']}_\u5bfe\u6226\u8868');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text('\u30c8\u30fc\u30ca\u30e1\u30f3\u30c8\u8868PDF'),
              subtitle: const Text('\u6c7a\u52dd\u30d6\u30e9\u30b1\u30c3\u30c8\u30fb\u7d50\u679c'),
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF\u3092\u751f\u6210\u4e2d...')));
                final bytes = await PdfGenerator().generateBracketPdf(_tournamentId);
                await PdfGenerator.sharePdf(bytes, '${widget.tournament['name']}_\u30c8\u30fc\u30ca\u30e1\u30f3\u30c8');
              },
            ),
          ]),
        ),
      ),
    );
    return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('シェアする', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildShareOption(icon: Icons.timeline, label: 'タイムライン', color: AppTheme.primaryColor, onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('タイムラインにシェアしました'), backgroundColor: AppTheme.success));
              }),
              _buildShareOption(icon: Icons.mail_outline, label: 'DMで送る', color: AppTheme.info, onTap: () => Navigator.pop(sheetContext)),
              _buildShareOption(icon: Icons.chat_bubble_outline, label: 'LINEで送る', color: const Color(0xFF06C755), onTap: () => Navigator.pop(sheetContext)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildShareOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ━━━ 共通ウィジェット ━━━
  Widget _buildCard({String? title, IconData? titleIcon, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            if (titleIcon != null) ...[
              Icon(titleIcon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
            ],
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ]),
          const SizedBox(height: 12),
        ],
        child,
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey[100]);
}
