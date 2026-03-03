import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'score_input_screen.dart';
import 'checkin_screen.dart';
import 'mvp_voting_screen.dart';
import 'tournament_finance_screen.dart';
import 'tournament_rules_screen.dart';
import 'venue_search_screen.dart';
import '../../services/csv_download.dart';
import '../../services/match_generator.dart';
import '../profile/user_profile_screen.dart';
import '../../services/pdf_generator.dart';
import '../home/create_post_screen.dart';
import 'package:printing/printing.dart';
import '../chat/chat_screen.dart';
import '../../services/notification_service.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final bool autoCheckIn;
  final String? initialTab; // 'overview', 'matches', 'standings', 'teams', 'board', 'photo'
  const TournamentDetailScreen({super.key, required this.tournament, this.autoCheckIn = false, this.initialTab});
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
  XFile? _selectedBoardImage;
  String _myEntryTeamId = "";
  bool _showOnlyMyCourts = true;
  Set<String> _myCourtIds = {};
  final Map<int, String?> _selectedCourtFilter = {}; // roundNum -> (null=全て, 'MY'=自分のコート, courtId=特定コート) default: MY
  final Map<int, bool> _collapsedRounds = {}; // roundNum -> 折りたたみ状態

  String get _tournamentId => widget.tournament['id'] as String? ?? '';

  int _resolveInitialTab() {
    final tab = widget.initialTab;
    if (tab == null) return 0;
    // 6タブ: 概要(0), 対戦表(1), 順位表(2), チーム(3), 掲示板(4), フォト(5)
    // 4タブ: 概要(0), チーム(1), 掲示板(2), フォト(3)
    if (_isEntryDeadlinePassed) {
      switch (tab) {
        case 'matches': return 1;
        case 'standings': return 2;
        case 'teams': return 3;
        case 'board': return 4;
        case 'photo': return 5;
        default: return 0;
      }
    } else {
      switch (tab) {
        case 'teams': return 1;
        case 'board': return 2;
        case 'photo': return 3;
        default: return 0;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final status = (widget.tournament['status'] as String?) ?? '';
    _isEntryDeadlinePassed = status == '満員' || status == '開催済み' || status == '開催中' || status == '決勝中' || status == '順位決定中' || status == '終了' || status.contains('完了') || widget.tournament['organizerId'] == FirebaseAuth.instance.currentUser?.uid;
    _isFollowing = widget.tournament['isFollowing'] as bool? ?? true;
    _tabController = TabController(
      length: _isEntryDeadlinePassed ? 6 : 4,
      vsync: this,
      initialIndex: _resolveInitialTab(),
    );
    _loadMyTeams().then((_) {
      if (mounted && widget.autoCheckIn) _performSelfCheckIn();
    });
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
    final allEntries = await _firestore.collection('tournaments').doc(_tournamentId)
        .collection('entries').get();
    // enteredBy OR memberUids にUIDが含まれるエントリーを検索
    final myDocs = allEntries.docs.where((d) {
      final data = d.data();
      if (data['enteredBy'] == uid) return true;
      final memberUids = data['memberUids'];
      if (memberUids is List && memberUids.contains(uid)) return true;
      return false;
    });
    final teamIds = myDocs.map((d) => d['teamId'] as String? ?? '').where((id) => id.isNotEmpty).toList();
    if (mounted) setState(() {
      _myTeamIds = teamIds;
      _myEntryTeamId = teamIds.isNotEmpty ? teamIds.first : "";
    });
  }
  /// セルフチェックイン（参加者がQRスキャンまたはボタンで自分のチームをチェックイン）
  Future<void> _performSelfCheckIn() async {
    if (_myEntryTeamId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この大会にエントリーしていないためチェックインできません'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    // 重複チェック
    final existing = await _firestore.collection('tournaments').doc(_tournamentId)
        .collection('checkIns').where('teamId', isEqualTo: _myEntryTeamId).limit(1).get();
    if (existing.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すでにチェックイン済みです'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    // チーム名取得
    final entrySnap = await _firestore.collection('tournaments').doc(_tournamentId)
        .collection('entries').where('teamId', isEqualTo: _myEntryTeamId).limit(1).get();
    final teamName = entrySnap.docs.isNotEmpty ? (entrySnap.docs.first.data()['teamName'] ?? '') : '';
    // チェックイン登録
    await _firestore.collection('tournaments').doc(_tournamentId).collection('checkIns').add({
      'teamId': _myEntryTeamId,
      'teamName': teamName,
      'checkedInAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$teamName チェックイン完了！'),
          ]),
          backgroundColor: AppTheme.success,
        ),
      );
    }
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
      case 'エントリー締切': statusColor = AppTheme.accentColor; break;
      case '準備中': statusColor = AppTheme.warning; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      case '決勝中': statusColor = Colors.amber; break;
      case '順位決定中': statusColor = Colors.amber; break;
      default: statusColor = AppTheme.textSecondary;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const SizedBox.shrink(),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () => _showShareOptions(context)),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _showPdfSheet(context)),
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
                _KeepAlivePage(child: _buildOverviewTab()),
                if (_isEntryDeadlinePassed) _KeepAlivePage(child: _buildMatchTableTab()),
                if (_isEntryDeadlinePassed) _KeepAlivePage(child: _buildStandingsTab()),
                _KeepAlivePage(child: _buildTeamsTab()),
                _KeepAlivePage(child: _buildTimelineTab()),
                _KeepAlivePage(child: _buildPhotoGalleryTab()),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primaryColor, AppTheme.primaryLight],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大会名 + ステータスバッジを1行に
          Row(
            children: [
              Expanded(
                child: Text((t['name'] ?? t['title'] ?? '') as String,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.accentColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Text((t['type'] ?? '') as String, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 日付・チーム数・場所を1行に
          Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text((t['date'] ?? '') as String, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(width: 12),
            const Icon(Icons.location_on, size: 13, color: Colors.white70),
            const SizedBox(width: 3),
            Expanded(
              child: Text(t['location'] as String? ?? t['venue'] as String? ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
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
      color: AppTheme.warning.withValues(alpha:0.1),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text('大会主催者をフォローするとエントリーできます', style: TextStyle(fontSize: 13, color: AppTheme.warning))),
          TextButton(
            onPressed: () {
              setState(() => _isFollowing = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('大会主催者をフォローしました！'), backgroundColor: AppTheme.success),
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
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          const Tab(text: '概要'),
          if (_isEntryDeadlinePassed) const Tab(text: '対戦表'),
          if (_isEntryDeadlinePassed) const Tab(text: '順位表'),
          const Tab(text: 'チーム'),
          const Tab(text: '掲示板'),
          const Tab(text: 'フォト'),
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
        final liveCourts = live['courts'] ?? courts;
        final liveDate = live['date'] as String? ?? t['date'] as String? ?? '';
        final liveLocation = live['location'] as String? ?? t['location'] as String? ?? t['venue'] as String? ?? '';
        final liveAddress = (live['venueAddress'] ?? t['venueAddress'] ?? '').toString();
        final liveType = live['type'] ?? t['type'] ?? '混合';
        final liveEntryFee = () { final f = live['entryFee'] ?? t['entryFee'] ?? t['fee']; return f is int ? '¥$f' : (f ?? '').toString(); }();
        final liveDeadline = (live['deadline'] ?? t['deadline'] ?? '').toString();
        final liveDescription = (live['description'] ?? t['description'] ?? '').toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ━━━ 大会情報カード ━━━
            _buildCard(
              title: '大会情報',
              titleIcon: Icons.info_outline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 日時
                _buildDetailInfoRow(Icons.calendar_today, '日時', liveDate),
                const Divider(height: 1),
                // 会場
                _buildDetailInfoRow(Icons.location_on, '会場', liveLocation, subtitle: liveAddress.isNotEmpty ? liveAddress : null, onSubtitleTap: liveAddress.isNotEmpty ? () {
                  final encoded = Uri.encodeComponent(liveAddress);
                  launchUrl(Uri.parse('https://www.google.com/maps/search/$encoded'), mode: LaunchMode.externalApplication);
                } : null),
                const Divider(height: 1),
                // 種別
                _buildDetailInfoRow(Icons.category, '種別', liveType),
                const Divider(height: 1),
                // 参加費
                _buildDetailInfoRow(Icons.payments, '参加費', liveEntryFee),
                const Divider(height: 1),
                // 募集チーム数
                _buildDetailInfoRow(Icons.groups, '募集チーム数', '$liveMaxTeams チーム'),
                const Divider(height: 1),
                // コート数
                _buildDetailInfoRow(Icons.grid_view, 'コート数', '${liveCourts}コート'),
                // 締切
                if (liveDeadline.isNotEmpty) ...[
                  const Divider(height: 1),
                  _buildDetailInfoRow(Icons.event_busy, 'エントリー締切', liveDeadline, valueColor: AppTheme.warning),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // ━━━ 募集状況 ━━━
            _buildCard(
              title: '募集状況',
              titleIcon: Icons.groups,
              child: Column(children: [
                Row(children: [
                  Text('$liveCurrentTeams', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text(' / $liveMaxTeams チーム', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: liveProgress >= 1.0 ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(liveProgress >= 1.0 ? '満員' : '残り${liveMaxTeams - liveCurrentTeams}枠',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
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
            const SizedBox(height: 16),

            // ━━━ 当日スケジュール（タイムライン形式） ━━━
            _buildCard(
              title: 'タイムスケジュール',
              titleIcon: Icons.schedule,
              child: Column(children: [
                _buildTimelineRow(live['openTime'] as String? ?? t['openTime'] as String? ?? '8:00', '会場オープン', Icons.location_on),
                _buildTimelineRow(live['receptionTime'] as String? ?? t['receptionTime'] as String? ?? '8:30', '受付開始', Icons.how_to_reg),
                _buildTimelineRow(live['captainMeetingTime'] as String? ?? t['captainMeetingTime'] as String? ?? '8:45', 'チームキャプテン会議', Icons.groups),
                _buildTimelineRow(live['openingTime'] as String? ?? t['openingTime'] as String? ?? '9:00', '開会式', Icons.campaign),
                _buildTimelineRow(live['matchStartTime'] as String? ?? t['matchStartTime'] as String? ?? '9:15', '試合開始', Icons.sports_volleyball),
                _buildTimelineRow(live['finalTime'] as String? ?? t['finalTime'] as String? ?? '15:00', '終了', Icons.flag),
                _buildTimelineRow(live['closingTime'] as String? ?? t['closingTime'] as String? ?? '15:30', '完全撤退', Icons.exit_to_app, isLast: true),
              ]),
            ),
            const SizedBox(height: 16),

            // ━━━ Organizer ━━━
            GestureDetector(
              onTap: () {
                final organizerId = live['organizerId'] as String? ?? t['organizerId'] as String?;
                if (organizerId != null && organizerId.isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: organizerId),
                  ));
                }
              },
              child: FutureBuilder<DocumentSnapshot>(
                future: (() {
                  final orgId = live['organizerId'] as String? ?? t['organizerId'] as String? ?? '';
                  return orgId.isNotEmpty ? _firestore.collection('users').doc(orgId).get() : null;
                })(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final avatarUrl = (userData['avatarUrl'] ?? '') as String;
                  final organizerName = live['organizerName'] as String? ?? t['organizer'] as String? ?? t['organizerName'] as String? ?? '主催者';
                  return _buildCard(
                child: Row(children: [
                  avatarUrl.isNotEmpty
                      ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatarUrl))
                      : CircleAvatar(radius: 22, backgroundColor: AppTheme.primaryColor.withValues(alpha:0.12),
                          child: Text(organizerName.isNotEmpty ? organizerName[0] : '主', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(organizerName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.star, size: 14, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text('大会主催者', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.textHint),
                ]),
              );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ━━━ Description ━━━
            if (liveDescription.isNotEmpty) ...[
              _buildCard(
                title: '大会説明・備考',
                titleIcon: Icons.description_outlined,
                child: Text(liveDescription,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 16),
            ],

            // ━━━ ルール ━━━
            _buildCard(
              title: 'ルール',
              titleIcon: Icons.gavel,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 予選
                () {
                  final rounds = livePrelim['rounds'] ?? 1;
                  final hasR2 = rounds == 2;
                  // 2ラウンド形式: round1/round2に分かれている
                  final r1Data = hasR2 ? (livePrelim['round1'] as Map<String, dynamic>? ?? {}) : livePrelim;
                  final r2Data = hasR2 ? (livePrelim['round2'] as Map<String, dynamic>? ?? {}) : <String, dynamic>{};
                  final r1Sets = r1Data['sets'] ?? 2;
                  final r2Sets = r2Data['sets'] ?? r1Sets;
                  final r1Deuce = r1Data['deuce'] ?? false;
                  final r2Deuce = r2Data['deuce'] ?? r1Deuce;
                  final r1DeuceCap = r1Data['deuceCap'] ?? 17;
                  final r2DeuceCap = r2Data['deuceCap'] ?? r1DeuceCap;

                  if (!hasR2) {
                    // 1ラウンドのみ
                    return _buildRuleSectionCard(
                      '予選',
                      Icons.sports_volleyball,
                      AppTheme.primaryColor,
                      [
                        _buildRuleTableRow('セット形式', _setFormatDisplayLabel(r1Sets)),
                        _buildRuleTableRow('デュース', r1Deuce ? 'あり（${r1DeuceCap}点キャップ）' : 'なし'),
                      ],
                    );
                  } else {
                    // 2ラウンド → ルールが同じなら1つにまとめる
                    final sameRules = r1Sets == r2Sets && r1Deuce == r2Deuce && r1DeuceCap == r2DeuceCap;
                    if (sameRules) {
                      return _buildRuleSectionCard(
                        '予選（ラウンド1・2共通）',
                        Icons.sports_volleyball,
                        AppTheme.primaryColor,
                        [
                          _buildRuleTableRow('セット形式', _setFormatDisplayLabel(r1Sets)),
                          _buildRuleTableRow('デュース', r1Deuce ? 'あり（${r1DeuceCap}点キャップ）' : 'なし'),
                        ],
                      );
                    }
                    return Column(children: [
                      _buildRuleSectionCard(
                        '予選 ラウンド1',
                        Icons.sports_volleyball,
                        AppTheme.primaryColor,
                        [
                          _buildRuleTableRow('セット形式', _setFormatDisplayLabel(r1Sets)),
                          _buildRuleTableRow('デュース', r1Deuce ? 'あり（${r1DeuceCap}点キャップ）' : 'なし'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildRuleSectionCard(
                        '予選 ラウンド2',
                        Icons.replay,
                        AppTheme.info,
                        [
                          _buildRuleTableRow('セット形式', _setFormatDisplayLabel(r2Sets)),
                          _buildRuleTableRow('デュース', r2Deuce ? 'あり（${r2DeuceCap}点キャップ）' : 'なし'),
                        ],
                      ),
                    ]);
                  }
                }(),
                // 勝ち点制
                if (liveScoring.isNotEmpty && (liveScoring['enabled'] ?? true)) ...[
                  const SizedBox(height: 10),
                  _buildScoringTable(livePrelim, liveScoring),
                ],
                // 順位決定戦
                if ((liveFinal['enabled'] ?? false) == true) ...[
                  const SizedBox(height: 10),
                  _buildRuleSectionCard(
                    '順位決定戦',
                    Icons.military_tech,
                    Colors.amber[700]!,
                    [
                      _buildRuleTableRow('方式', liveFinal['type'] == 'round_robin' ? '総当たり' : 'トーナメント'),
                      _buildRuleTableRow('セット形式', _setFormatDisplayLabel(liveFinal['sets'] ?? 3)),
                      _buildRuleTableRow('デュース', (liveFinal['deuce'] ?? false) ? 'あり' : 'なし'),
                      if (liveFinal['format'] == '順位別複数') ...[
                        _buildRuleTableRow('区分数', '${liveFinal['tierCount'] ?? 3}区分'),
                        _buildTierInfoRow(liveFinal['tierCount'] as int? ?? 3, liveMaxTeams),
                      ],
                    ],
                  ),
                ],
                // その他
                if (liveOther.isNotEmpty && (liveOther['uniformNumber'] != null || liveOther['snsVideo'] != null)) ...[
                  const SizedBox(height: 10),
                  _buildRuleSectionCard(
                    'その他',
                    Icons.more_horiz,
                    AppTheme.textSecondary,
                    [
                      if (liveOther['uniformNumber'] != null)
                        _buildRuleTableRow('ゼッケン', liveOther['uniformNumber'] == true ? '必須' : '不要'),
                      if (liveOther['snsVideo'] != null)
                        _buildRuleTableRow('SNS動画投稿', liveOther['snsVideo'] == true ? '許可' : '不可'),
                    ],
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // ━━━ ルールPDF ━━━
            if ((live['rulesPdfUrl'] ?? t['rulesPdfUrl']) != null) ...[
              _buildCard(
                title: 'ルールPDF',
                titleIcon: Icons.picture_as_pdf,
                child: GestureDetector(
                  onTap: () {
                    final url = (live['rulesPdfUrl'] ?? t['rulesPdfUrl']) as String;
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf, color: AppTheme.error, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((live['rulesPdfName'] ?? t['rulesPdfName'] ?? 'ルール.pdf') as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('タップしてPDFを開く', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ])),
                      Icon(Icons.open_in_new, size: 18, color: AppTheme.primaryColor),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ━━━ 大会の流れ ━━━
            _buildCard(
              title: '大会の流れ',
              titleIcon: Icons.timeline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildFlowStep(1, 'エントリー受付', liveStatus == '募集中', liveCurrentTeams > 0),
                _buildFlowStep(2, 'エントリー締切', liveStatus == 'エントリー締切', liveStatus == 'エントリー締切' || liveStatus == '開催中' || liveStatus == '終了'),
                _buildFlowStep(3, '予選リーグ', liveStatus == '開催中', false),
                if ((livePrelim['rounds'] ?? 1) > 1)
                  _buildFlowStep(4, '予選2', false, false),
                _buildFlowStep((livePrelim['rounds'] ?? 1) > 1 ? 5 : 4, '順位決定戦', liveStatus == '順位決定中', false),
                _buildFlowStep((livePrelim['rounds'] ?? 1) > 1 ? 6 : 5, '結果発表・表彰', liveStatus == '終了', false, isLast: true),
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
                      return const Text('順位決定戦のデータがまだありません', style: TextStyle(color: AppTheme.textSecondary));
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
                            if (finalMatch == null) return const Text('順位決定戦が完了していません');
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
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => MvpVotingScreen(
                                      tournamentId: _tournamentId,
                                      tournamentName: widget.tournament['title'] ?? widget.tournament['name'] ?? '',
                                    ),
                                  )),
                                  icon: const Icon(Icons.how_to_vote, size: 18),
                                  label: const Text('MVP投票'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showImpressionModal(),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('感想を投稿する'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showImpressionModal() {
    final t = widget.tournament;
    final tournamentName = t['name'] ?? '大会';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          tournamentId: _tournamentId,
          tournamentName: tournamentName,
        ),
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String team, Color color) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
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

  static String _setFormatDisplayLabel(int sets) {
    switch (sets) {
      case 1: return '1セットマッチ';
      case 3: return '2セット先取';
      default: return '2セットマッチ';
    }
  }

  List<Widget> _buildScoringRowsForFormat(int sets, Map<String, dynamic> scoring) {
    switch (sets) {
      case 1:
        return [
          _buildPointRow('勝利', scoring['win'] ?? 3),
          _buildPointRow('敗北', scoring['lose'] ?? 0),
        ];
      case 3:
        return [
          _buildPointRow('2-0 勝ち', scoring['win20'] ?? 10),
          _buildPointRow('2-1 勝ち', scoring['win21'] ?? 7),
          _buildPointRow('1-2 負け', scoring['lose12'] ?? 2),
          _buildPointRow('0-2 負け', scoring['lose02'] ?? 0),
        ];
      default:
        return [
          _buildPointRow('2-0 勝ち', scoring['win20'] ?? 10),
          _buildPointRow('1-1 得失差勝ち', scoring['win11'] ?? 7),
          _buildPointRow('1-1 引き分け', scoring['draw'] ?? 4),
          _buildPointRow('1-1 得失差負け', scoring['lose11'] ?? 2),
          _buildPointRow('0-2 負け', scoring['lose02'] ?? 0),
        ];
    }
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
        final tournEditors = List<String>.from(tournData['editors'] ?? []);
        final isOrganizer = tournData['organizerId'] == uid || tournEditors.contains(uid);
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
                  Text(status == '募集中' || status == 'エントリー締切' ? '対戦表はエントリー締切後に生成されます' : '対戦表を生成してください',
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



  // ━━━ 順位表タブ（全予選合計） ━━━
  Widget _buildStandingsTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).collection('rounds').snapshots(),
      builder: (context, roundsSnap) {
        if (!roundsSnap.hasData) return const Center(child: CircularProgressIndicator());
        final rounds = roundsSnap.data!.docs;
        if (rounds.isEmpty) {
          return const Center(child: Text('予選がまだ生成されていません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)));
        }

        final roundIds = rounds.map((d) => d.id).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _OverallStandingsAggregator(
            tournamentId: _tournamentId,
            roundIds: roundIds,
            myTeamIds: _myTeamIds,
          ),
        );
      },
    );
  }

  // ━━━ ステータス変更 ━━━
  void _showStatusDialog(String currentStatus) {
    final statuses = ['準備中', '募集中', 'エントリー締切', '開催中', '終了'];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ステータス変更', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: statuses.map((s) {
        return RadioListTile<String>(title: Text(s), value: s, groupValue: currentStatus, activeColor: AppTheme.primaryColor,
          onChanged: (v) async {
            if (v != null) {
              await _firestore.collection('tournaments').doc(_tournamentId).update({'status': v});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ステータスを「$v」に変更しました'), backgroundColor: AppTheme.success));
            }
          });
      }).toList()),
    ));
  }

  // ━━━ 削除 ━━━
  void _showDeleteDialog(String title) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('大会を削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Text('「$title」を削除しますか？\nこの操作は取り消せません。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary))),
        ElevatedButton(
          onPressed: () async {
            await _firestore.collection('tournaments').doc(_tournamentId).delete();
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$title」を削除しました'), backgroundColor: AppTheme.error));
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
          child: const Text('削除する'),
        ),
      ],
    ));
  }

  // ━━━ テンプレートに保存 ━━━
  Future<void> _saveAsTemplate(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final title = data['title'] ?? '大会';
    final rules = data['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};

    await _firestore.collection('users').doc(uid).collection('templates').add({
      'name': '$titleのテンプレート',
      'type': data['type'] ?? '混合',
      'maxTeams': data['maxTeams'] ?? 8,
      'setCount': (preliminary['sets'] ?? '3').toString(),
      'pointsPerSet': (preliminary['pointsPerSet'] ?? '25').toString(),
      'location': data['location'] ?? '',
      'memo': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートに保存しました'), backgroundColor: AppTheme.success),
      );
    }
  }

  // ━━━ 大会編集シート ━━━
  InputDecoration _sheetInputDecoration(String hint) {
    return InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint),
      filled: true, fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
  }

  void _showEditTournamentSheet(Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final locationCtrl = TextEditingController(text: data['location'] ?? '');
    final rawFee = data['entryFee'];
    final feeCtrl = TextEditingController(text: (rawFee is int ? rawFee : int.tryParse(rawFee.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toString());
    final maxTeamsCtrl = TextEditingController(text: (data['maxTeams'] ?? 8).toString());
    final courtsCtrl = TextEditingController(text: (data['courts'] ?? 2).toString());
    String selectedType = data['type'] ?? '混合';
    String selectedDate = data['date'] ?? '';
    Map<String, dynamic>? tournamentRules = (data['rules'] is Map) ? Map<String, dynamic>.from(data['rules']) : null;
    Map<String, dynamic>? selectedVenue;
    if (data['venueId'] != null && (data['venueId'] as String).isNotEmpty) {
      selectedVenue = {'id': data['venueId'], 'name': data['location'], 'address': data['venueAddress'] ?? ''};
    }

    // 初期値を保存して変更検出に使う
    final origTitle = titleCtrl.text;
    final origLocation = locationCtrl.text;
    final origFee = feeCtrl.text;
    final origMaxTeams = maxTeamsCtrl.text;
    final origCourts = courtsCtrl.text;
    final origType = selectedType;
    final origDate = selectedDate;
    final origRules = tournamentRules;
    final origVenue = selectedVenue;

    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setPageState) {
        bool hasChanges() {
          return titleCtrl.text != origTitle || locationCtrl.text != origLocation ||
              feeCtrl.text != origFee || maxTeamsCtrl.text != origMaxTeams ||
              courtsCtrl.text != origCourts || selectedType != origType ||
              selectedDate != origDate || tournamentRules != origRules || selectedVenue != origVenue;
        }

        Future<bool> onWillPop() async {
          if (!hasChanges()) return true;
          final result = await showDialog<String>(
            context: ctx,
            builder: (dlgCtx) => AlertDialog(
              title: const Text('編集内容の保存'),
              content: const Text('変更が保存されていません。保存してから閉じますか？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dlgCtx, 'discard'), child: const Text('保存しない', style: TextStyle(color: AppTheme.textSecondary))),
                TextButton(onPressed: () => Navigator.pop(dlgCtx, 'cancel'), child: const Text('編集に戻る')),
                ElevatedButton(
                  onPressed: titleCtrl.text.trim().isNotEmpty && selectedDate.isNotEmpty && locationCtrl.text.trim().isNotEmpty
                      ? () => Navigator.pop(dlgCtx, 'save') : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('保存する'),
                ),
              ],
            ),
          );
          if (result == 'save') {
            await _firestore.collection('tournaments').doc(_tournamentId).update({
              'title': titleCtrl.text.trim(), 'date': selectedDate, 'location': locationCtrl.text.trim(),
              'courts': int.tryParse(courtsCtrl.text) ?? 2, 'maxTeams': int.tryParse(maxTeamsCtrl.text) ?? 8,
              'entryFee': int.tryParse(feeCtrl.text.trim()) ?? 0, 'type': selectedType,
              'venueId': selectedVenue?['id'] ?? '', 'venueAddress': selectedVenue?['address'] ?? '',
              'rules': tournamentRules ?? {},
            });
            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('大会情報を更新しました！'), backgroundColor: AppTheme.success));
            return true;
          }
          return result == 'discard';
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldPop = await onWillPop();
            if (shouldPop && ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final shouldPop = await onWillPop();
                  if (shouldPop && ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              title: const Text('大会を編集', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              centerTitle: true,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('大会名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, maxLength: 30, onChanged: (_) => setPageState(() {}), decoration: _sheetInputDecoration('大会名を入力')),
              const SizedBox(height: 8),
              const Text('開催日 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setPageState(() => selectedDate = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary), const SizedBox(width: 10),
                    Text(selectedDate.isEmpty ? '日付を選択' : selectedDate, style: TextStyle(fontSize: 15, color: selectedDate.isEmpty ? AppTheme.textHint : AppTheme.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text('会場 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(ctx, MaterialPageRoute(builder: (_) => const VenueSearchScreen(pickerMode: true)));
                  if (result != null) setPageState(() { selectedVenue = result; locationCtrl.text = result['name'] ?? ''; courtsCtrl.text = (result['courts'] ?? courtsCtrl.text).toString(); });
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(selectedVenue != null ? Icons.check_circle : Icons.search, size: 18, color: selectedVenue != null ? AppTheme.success : AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(locationCtrl.text.isNotEmpty ? locationCtrl.text : '会場を探す',
                        style: TextStyle(fontSize: 15, color: locationCtrl.text.isNotEmpty ? AppTheme.textPrimary : AppTheme.textHint))),
                  ]),
                ),
              ),
              if (selectedVenue != null && (selectedVenue!['address'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(selectedVenue!['address'], style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('使用コート数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: courtsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('2'),
                    onChanged: (_) => setPageState(() {})),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('募集チーム数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: maxTeamsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('8'),
                    onChanged: (_) => setPageState(() {})),
                ])),
              ]),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final courts = int.tryParse(courtsCtrl.text) ?? 2;
                final teams = int.tryParse(maxTeamsCtrl.text) ?? 8;
                final tpc = courts > 0 ? (teams / courts).ceil() : teams;
                return Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                  child: Text('1コート $tpc チーム（自動計算）', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                );
              }),
              const SizedBox(height: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('参加費（円）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('3000')),
              ]),
              const SizedBox(height: 16),
              const Text('カテゴリ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['混合', 'メンズ', 'レディース'].map((t) {
                return ChoiceChip(label: Text(t), selected: selectedType == t,
                    onSelected: (s) { if (s) setPageState(() => selectedType = t); },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15));
              }).toList()),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context,
                    MaterialPageRoute(builder: (_) => TournamentRulesScreen(initialRules: tournamentRules, courtCount: int.tryParse(courtsCtrl.text), maxTeams: int.tryParse(maxTeamsCtrl.text), entryFee: int.tryParse(feeCtrl.text))));
                  if (result != null) setPageState(() { tournamentRules = result; });
                },
                icon: Icon(tournamentRules != null ? Icons.check_circle : Icons.tune, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                label: Text(tournamentRules != null ? 'ルール設定済み' : 'ルールを設定する',
                    style: TextStyle(fontWeight: FontWeight.w600, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: titleCtrl.text.trim().isNotEmpty && selectedDate.isNotEmpty && locationCtrl.text.trim().isNotEmpty
                    ? () async {
                        await _firestore.collection('tournaments').doc(_tournamentId).update({
                          'title': titleCtrl.text.trim(), 'date': selectedDate, 'location': locationCtrl.text.trim(),
                          'courts': int.tryParse(courtsCtrl.text) ?? 2, 'maxTeams': int.tryParse(maxTeamsCtrl.text) ?? 8,
                          'entryFee': int.tryParse(feeCtrl.text.trim()) ?? 0, 'type': selectedType,
                          'venueId': selectedVenue?['id'] ?? '', 'venueAddress': selectedVenue?['address'] ?? '',
                          'rules': tournamentRules ?? {},
                        });
                        if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('大会情報を更新しました！'), backgroundColor: AppTheme.success)); }
                      } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
            ])),
          ),
        );
      }),
    ));
  }

  // ━━━ CSVテンプレートダウンロード ━━━
  Future<void> _downloadCsvTemplate() async {
    const header = 'チーム名,チームキャプテン,メンバー1,メンバー2,メンバー3,メンバー4,メンバー5,メンバー6';
    const example1 = 'サンプルチームA,佐藤花子,田中太郎,佐藤花子,鈴木一郎,高橋美咲,,';
    const example2 = 'サンプルチームB,伊藤さくら,山田次郎,伊藤さくら,渡辺健太,中村あい,小林大輔,';
    final csvContent = '$header\n$example1\n$example2\n';

    try {
      await downloadCsvFile(csvContent, 'entry_template.csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テンプレートの作成に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ━━━ CSV一括登録 ━━━
  Future<void> _importTeamsFromCsv() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      // Shift_JIS等のエンコーディングの場合はlatin1でデコード
      csvString = latin1.decode(bytes);
    }

    final rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVファイルが空です'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // ヘッダー行をスキップするか判定
    final firstRow = rows.first;
    final hasHeader = firstRow.isNotEmpty &&
        (firstRow[0].toString().contains('チーム') || firstRow[0].toString().toLowerCase().contains('team'));

    // 「チームキャプテン」列があるか判定（2列目がキャプテン列）
    final hasCaptainCol = hasHeader && firstRow.length >= 2 &&
        (firstRow[1].toString().contains('キャプテン') || firstRow[1].toString().toLowerCase().contains('captain'));

    final dataRows = hasHeader ? rows.skip(1).toList() : rows;

    if (dataRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録するチームがありません'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // パース結果をプレビュー
    final teams = <Map<String, dynamic>>[];
    for (final row in dataRows) {
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
      final teamName = row[0].toString().trim();
      final captainName = hasCaptainCol && row.length >= 2 ? row[1].toString().trim() : '';
      final memberStartIdx = hasCaptainCol ? 2 : 1;
      final members = <String, String>{};
      int memberNum = 1;
      for (int i = memberStartIdx; i < row.length; i++) {
        final name = row[i].toString().trim();
        if (name.isNotEmpty) {
          members['p$memberNum'] = name;
          memberNum++;
        }
      }
      teams.add({
        'teamName': teamName,
        'captainName': captainName,
        'members': members,
        'memberCount': members.length,
      });
    }

    if (teams.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効なチームデータがありません'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // プレビューダイアログ（自分のチームを選択可能）
    if (!mounted) return;
    int? myTeamIndex;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.upload_file, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${teams.length}チームを登録', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.red[400]),
                  const SizedBox(width: 6),
                  Expanded(child: Text('自分のチームをタップして選択', style: TextStyle(fontSize: 12, color: Colors.red[400]))),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (ctx, i) {
                    final t = teams[i];
                    final members = t['members'] as Map<String, String>;
                    final isMyTeam = myTeamIndex == i;
                    return ListTile(
                      dense: true,
                      selected: isMyTeam,
                      selectedTileColor: Colors.red.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isMyTeam ? Colors.red.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMyTeam ? Colors.red : AppTheme.primaryColor)),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(t['teamName'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isMyTeam ? Colors.red : null))),
                        if (isMyTeam)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: const Text('自分', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                      ]),
                      subtitle: Text(members.values.join(', '), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      onTap: () => setDialogState(() => myTeamIndex = isMyTeam ? null : i),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Firestoreに一括登録
    int count = 0;
    final batch = _firestore.batch();
    for (int i = 0; i < teams.length; i++) {
      final t = teams[i];
      final entryRef = _firestore.collection('tournaments').doc(_tournamentId).collection('entries').doc();
      final captain = (t['captainName'] as String? ?? '').isNotEmpty
          ? t['captainName'] as String
          : (t['members'] as Map<String, String>).values.firstOrNull ?? '';
      batch.set(entryRef, {
        'teamId': entryRef.id,
        'teamName': t['teamName'],
        'leaderName': captain,
        'memberCount': t['memberCount'],
        'memberNames': t['members'],
        'enteredBy': i == myTeamIndex ? uid : '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      count++;
    }
    // currentTeamsを更新
    final tournRef = _firestore.collection('tournaments').doc(_tournamentId);
    batch.update(tournRef, {'currentTeams': FieldValue.increment(count)});

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$countチームをCSVから登録しました'), backgroundColor: AppTheme.success),
      );
    }
  }

  /// 対戦表CSVインポート（予選用）
  Future<void> _importMatchTableFromCsv({int roundNumber = 1}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      csvString = latin1.decode(bytes);
    }

    final rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVファイルが空です'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // Parse match rows - detect format
    final matchRows = <Map<String, String>>[];
    final firstRow = rows.first;
    final firstCell = firstRow.isNotEmpty ? firstRow[0].toString().trim() : '';

    if (firstCell.contains('コート') || firstCell.toLowerCase().contains('court')) {
      // フラット形式: コート,試合順,チームA,チームB,審判,サブ
      final dataRows = rows.skip(1).toList();
      for (final row in dataRows) {
        if (row.length < 4) continue;
        final court = row[0].toString().trim();
        final order = row[1].toString().trim();
        final teamA = row[2].toString().trim();
        final teamB = row[3].toString().trim();
        final referee = row.length > 4 ? row[4].toString().trim() : '';
        final sub = row.length > 5 ? row[5].toString().trim() : '';
        if (teamA.isEmpty || teamB.isEmpty) continue;
        matchRows.add({'court': court, 'matchOrder': order, 'teamA': teamA, 'teamB': teamB, 'referee': referee, 'subReferee': sub});
      }
    } else {
      // スプレッドシート横並び形式を自動検出
      matchRows.addAll(_parseSpreadsheetFormat(rows));
    }

    if (matchRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対戦データを読み取れませんでした'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // エントリー済みチーム名を取得して照合チェック
    final entriesSnap = await _firestore.collection('tournaments').doc(_tournamentId).collection('entries').get();
    final entryNames = entriesSnap.docs.map((d) => (d.data()['teamName'] as String? ?? '').trim()).toSet();

    final allTeamNames = <String>{};
    for (var m in matchRows) {
      allTeamNames.add(m['teamA']!);
      allTeamNames.add(m['teamB']!);
    }
    final unmatched = allTeamNames.where((n) => !entryNames.contains(n)).toList();

    // プレビューダイアログ
    if (!mounted) return;
    final courtCount = matchRows.map((m) => m['court']).toSet().length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.table_chart, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('予選$roundNumber 対戦表インポート', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$courtCountコート / ${matchRows.length}試合', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('${allTeamNames.length}チーム', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ]),
              ),
              if (unmatched.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('未登録チーム (${unmatched.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                    Text(unmatched.join(', '), style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: matchRows.length,
                  itemBuilder: (_, i) {
                    final m = matchRows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          alignment: Alignment.center,
                          child: Text(m['court']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        ),
                        const SizedBox(width: 6),
                        Text('${m['matchOrder']}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${m['teamA']} vs ${m['teamB']}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('インポート'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // インポート実行
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      await MatchGenerator().importMatchTable(
        tournamentId: _tournamentId,
        roundNumber: roundNumber,
        matchRows: matchRows,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('対戦表をインポートしました（${matchRows.length}試合）'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// スプレッドシート横並びフォーマットのパース
  /// 例: Aコート,,,,,,Bコート,,,,,,
  ///     第1試合,,,審判,サブ,,第1試合,,,審判,サブ
  ///     テリー,-,GENYA-2,掛川クラブ,こやまーず,,ビンチトーレ,-,ブルースカイ,3MA,わっち
  List<Map<String, String>> _parseSpreadsheetFormat(List<List<dynamic>> rows) {
    final matchRows = <Map<String, String>>[];

    // 1. コートヘッダー行を検出（「コート」を含む行）
    // 各ブロックは: コートヘッダー行 → (試合行ペア: 試合番号行 + データ行) × N
    int i = 0;
    while (i < rows.length) {
      final row = rows[i];
      // コートヘッダー行を探す（「コート」を含むセルがある行）
      final courtNames = <int, String>{}; // columnIndex → courtLetter
      for (int col = 0; col < row.length; col++) {
        final cell = row[col].toString().trim();
        if (cell.contains('コート') && cell.isNotEmpty) {
          // "Aコート" → "A"
          final letter = cell.replaceAll('コート', '').trim();
          courtNames[col] = letter.isNotEmpty ? letter : String.fromCharCode(65 + courtNames.length);
        }
      }

      if (courtNames.isEmpty) {
        i++;
        continue;
      }

      // コートのスタート列を特定
      final courtStarts = courtNames.keys.toList()..sort();
      i++; // コートヘッダー行をスキップ

      // 試合データを読む（試合番号行 + データ行のペア）
      int matchOrder = 0;
      while (i < rows.length) {
        final testRow = rows[i];
        final testCell = testRow.isNotEmpty ? testRow[0].toString().trim() : '';

        // 次のコートヘッダーが来たら終了
        if (testCell.contains('コート') && !testCell.contains('試合')) break;

        // 「第N試合」行の場合、次の行がデータ行
        if (testCell.contains('試合')) {
          matchOrder++;
          i++;
          if (i >= rows.length) break;

          final dataRow = rows[i];
          // 各コートのデータを読み取る
          for (int ci = 0; ci < courtStarts.length; ci++) {
            final startCol = courtStarts[ci];
            final courtLetter = courtNames[startCol]!;

            // dataRow[startCol+0]=チームA, [+1]="-", [+2]=チームB, [+3]=審判, [+4]=サブ
            final teamA = (startCol < dataRow.length) ? dataRow[startCol].toString().trim() : '';
            final teamB = (startCol + 2 < dataRow.length) ? dataRow[startCol + 2].toString().trim() : '';
            final referee = (startCol + 3 < dataRow.length) ? dataRow[startCol + 3].toString().trim() : '';
            final subRef = (startCol + 4 < dataRow.length) ? dataRow[startCol + 4].toString().trim() : '';

            if (teamA.isNotEmpty && teamB.isNotEmpty && teamA != '-' && teamB != '-') {
              matchRows.add({
                'court': courtLetter,
                'matchOrder': matchOrder.toString(),
                'teamA': teamA,
                'teamB': teamB,
                'referee': referee,
                'subReferee': subRef,
              });
            }
          }
          i++;
        } else {
          i++;
        }
      }
    }

    return matchRows;
  }

  /// 決勝対戦表CSVインポート
  Future<void> _importFinalsFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      csvString = latin1.decode(bytes);
    }

    final rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVファイルが空です'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // フォーマット: ブラケット名,試合番号,ラウンド,チームA,チームB
    // 例: 上位,1,semi,チームA,チームD
    final hasHeader = rows.first.isNotEmpty &&
        (rows.first[0].toString().contains('ブラケット') || rows.first[0].toString().toLowerCase().contains('bracket'));
    final dataRows = hasHeader ? rows.skip(1).toList() : rows;

    // パース
    final bracketData = <String, List<Map<String, String>>>{};
    for (final row in dataRows) {
      if (row.length < 5) continue;
      final bracketName = row[0].toString().trim();
      final matchNumber = row[1].toString().trim();
      final round = row[2].toString().trim();
      final teamA = row[3].toString().trim();
      final teamB = row[4].toString().trim();
      if (bracketName.isEmpty || teamA.isEmpty || teamB.isEmpty) continue;
      bracketData.putIfAbsent(bracketName, () => []);
      bracketData[bracketName]!.add({
        'matchNumber': matchNumber,
        'round': round,
        'teamA': teamA,
        'teamB': teamB,
      });
    }

    if (bracketData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('決勝データを読み取れませんでした'), backgroundColor: AppTheme.error),
        );
      }
      return;
    }

    // エントリー済みチーム名を取得
    final entriesSnap = await _firestore.collection('tournaments').doc(_tournamentId).collection('entries').get();
    final nameToId = <String, String>{};
    for (var d in entriesSnap.docs) {
      final data = d.data();
      final name = (data['teamName'] as String? ?? '').trim();
      nameToId[name] = data['teamId'] ?? d.id;
    }

    final totalMatches = bracketData.values.fold<int>(0, (sum, list) => sum + list.length);

    // プレビュー
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.emoji_events, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Expanded(child: Text('決勝対戦表インポート', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('${bracketData.length}ブラケット / $totalMatches試合', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: bracketData.entries.map((e) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        ...e.value.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 2),
                          child: Text('${m['round']}#${m['matchNumber']}: ${m['teamA']} vs ${m['teamB']}',
                              style: const TextStyle(fontSize: 12)),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('インポート'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Firestore に書き込み
    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));

      int bracketNum = 0;
      for (var entry in bracketData.entries) {
        bracketNum++;
        final bracketRef = _firestore.collection('tournaments').doc(_tournamentId)
            .collection('brackets').doc('bracket_$bracketNum');

        await bracketRef.set({
          'bracketNumber': bracketNum,
          'bracketName': entry.key,
          'teamCount': entry.value.expand((m) => [m['teamA']!, m['teamB']!]).toSet().length,
          'type': 'tournament',
          'status': 'pending',
        });

        for (var m in entry.value) {
          final teamAName = m['teamA']!;
          final teamBName = m['teamB']!;
          await bracketRef.collection('matches').add({
            'round': m['round'] ?? 'semi',
            'matchNumber': int.tryParse(m['matchNumber'] ?? '1') ?? 1,
            'teamAId': nameToId[teamAName] ?? teamAName,
            'teamAName': teamAName,
            'teamBId': nameToId[teamBName] ?? teamBName,
            'teamBName': teamBName,
            'status': 'pending',
            'sets': [],
            'result': {},
          });
        }
      }

      await _firestore.collection('tournaments').doc(_tournamentId).update({'status': '順位決定中'});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('決勝対戦表をインポートしました（$totalMatches試合）'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// 予選対戦表CSVテンプレートダウンロード
  Future<void> _downloadMatchTableTemplate() async {
    const header = 'コート,試合順,チームA,チームB,審判,サブ';
    const example = '''A,1,チームA,チームB,チームC,チームD
A,2,チームC,チームD,チームA,チームB
A,3,チームA,チームD,チームC,チームB
A,4,チームB,チームC,チームA,チームD
A,5,チームA,チームC,チームD,チームB
A,6,チームD,チームB,チームA,チームC
B,1,チームE,チームF,チームG,チームH
B,2,チームG,チームH,チームE,チームF''';
    final csvContent = '$header\n$example\n';

    try {
      await downloadCsvFile(csvContent, 'match_table_template.csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テンプレートの作成に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// 決勝対戦表CSVテンプレートダウンロード
  Future<void> _downloadFinalsTemplate() async {
    const header = 'ブラケット名,試合番号,ラウンド,チームA,チームB';
    const example = '''上位,1,semi,チームA,チームD
上位,2,semi,チームB,チームC
上位,3,final,準決勝①勝者,準決勝②勝者
中位,1,semi,チームE,チームH
中位,2,semi,チームF,チームG
中位,3,final,準決勝①勝者,準決勝②勝者''';
    final csvContent = '$header\n$example\n';

    try {
      await downloadCsvFile(csvContent, 'finals_template.csv');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テンプレートの作成に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  /// CSVインポートメニュー画面を表示
  void _showCsvImportMenu() {
    final rules = widget.tournament['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final prelimRounds = preliminary['rounds'] ?? 1;
    final finalEnabled = (rules['final'] as Map<String, dynamic>?)?['enabled'] ?? true;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CsvImportMenuScreen(
        prelimRounds: prelimRounds is int ? prelimRounds : 1,
        finalEnabled: finalEnabled is bool ? finalEnabled : true,
        onEntryUpload: _importTeamsFromCsv,
        onEntryTemplate: _downloadCsvTemplate,
        onMatchTableUpload1: () => _importMatchTableFromCsv(roundNumber: 1),
        onMatchTableUpload2: () => _importMatchTableFromCsv(roundNumber: 2),
        onMatchTableTemplate: _downloadMatchTableTemplate,
        onFinalsUpload: _importFinalsFromCsv,
        onFinalsTemplate: _downloadFinalsTemplate,
      ),
    ));
  }

  void _showEditorsSheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('編集者を管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('編集権限を持つユーザーは大会情報を編集できます', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // 現在の編集者リスト
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('tournaments').doc(_tournamentId).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final tournData = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final editors = List<String>.from(tournData['editors'] ?? []);

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('編集者 ${editors.length}人', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (editors.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('まだ編集者がいません', style: TextStyle(color: AppTheme.textHint))),
                      )
                    else
                      ...editors.map((editorUid) => FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(editorUid).get(),
                        builder: (context, userSnap) {
                          final name = userSnap.data?.data() != null
                              ? ((userSnap.data!.data() as Map<String, dynamic>)['nickname'] ?? '名前なし')
                              : '読み込み中...';
                          final avatar = userSnap.data?.data() != null
                              ? ((userSnap.data!.data() as Map<String, dynamic>)['avatarUrl'] ?? '').toString()
                              : '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: avatar.isNotEmpty
                                ? CircleAvatar(radius: 18, backgroundImage: NetworkImage(avatar))
                                : CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    child: Text(name.toString().isNotEmpty ? name.toString()[0] : '?',
                                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))),
                            title: Text(name.toString(), style: const TextStyle(fontSize: 14)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                              onPressed: () async {
                                await _firestore.collection('tournaments').doc(_tournamentId).update({
                                  'editors': FieldValue.arrayRemove([editorUid]),
                                });
                                setSheetState(() {});
                              },
                            ),
                          );
                        },
                      )),
                  ]);
                },
              ),
              const SizedBox(height: 16),

              // フォロワーから追加
              const Text('フォロー中から追加', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').doc(uid).collection('following').snapshots(),
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
                  return StreamBuilder<DocumentSnapshot>(
                    stream: _firestore.collection('tournaments').doc(_tournamentId).snapshots(),
                    builder: (context, tournSnap) {
                      final currentEditors = List<String>.from(
                          (tournSnap.data?.data() as Map<String, dynamic>?)?['editors'] ?? []);
                      return Container(
                        constraints: const BoxConstraints(maxHeight: 200),
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
                            final isAlreadyEditor = currentEditors.contains(fUid);

                            return ListTile(
                              leading: fAvatar.toString().isNotEmpty
                                  ? CircleAvatar(backgroundImage: NetworkImage(fAvatar.toString()), radius: 18)
                                  : CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      child: Text(fName.toString().isNotEmpty ? fName.toString()[0] : '?',
                                          style: const TextStyle(color: AppTheme.primaryColor))),
                              title: Text(fName.toString(), style: const TextStyle(fontSize: 14)),
                              trailing: isAlreadyEditor
                                  ? const Icon(Icons.check_circle, color: AppTheme.success)
                                  : IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                                      onPressed: () async {
                                        await _firestore.collection('tournaments').doc(_tournamentId).update({
                                          'editors': FieldValue.arrayUnion([fUid]),
                                        });
                                        setSheetState(() {});
                                      },
                                    ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ]),
          );
        });
      },
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

  void _showAnnouncementDialog() {
    final messageCtrl = TextEditingController();
    final t = widget.tournament;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.campaign, color: AppTheme.accentColor, size: 22),
          const SizedBox(width: 8),
          const Text('お知らせを送信', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全参加者に通知が届きます', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '例: 持ち物の確認、集合場所の変更など',
                hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                filled: true, fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.check_circle_outline, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('掲示板にも同時投稿されます', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final message = messageCtrl.text.trim();
              if (message.isEmpty) return;
              Navigator.pop(ctx);

              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final userDoc = await _firestore.collection('users').doc(uid).get();
              final nickname = userDoc.data()?['nickname'] ?? '主催者';
              final avatar = (userDoc.data()?['avatarUrl'] ?? '') as String;

              // 掲示板に投稿（ピン留め＋お知らせラベル付き）
              await _firestore.collection('tournaments').doc(_tournamentId).collection('timeline').add({
                'authorId': uid,
                'authorName': nickname,
                'authorAvatar': avatar,
                'text': message,
                'isOrganizer': true,
                'pinned': true,
                'isAnnouncement': true,
                'likesCount': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });

              // 全参加者に通知
              NotificationService.sendTournamentAnnouncement(
                tournamentId: _tournamentId,
                tournamentName: t['name'] as String? ?? t['title'] as String? ?? '',
                senderId: uid,
                senderName: nickname,
                message: message,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('お知らせを送信しました'), backgroundColor: AppTheme.success),
                );
              }
            },
            icon: const Icon(Icons.send, size: 16),
            label: const Text('送信'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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
              // 全参加者に結果通知 + タイムライン自動投稿
              final t = widget.tournament;
              NotificationService.sendTournamentEndNotification(
                tournamentId: _tournamentId,
                tournamentName: t['name'] as String? ?? t['title'] as String? ?? '',
                tournamentDate: t['date'] as String? ?? '',
                organizerId: t['organizerId'] as String? ?? '',
                organizerName: t['organizerName'] as String? ?? '',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('大会を終了しました。参加者に通知を送信しました'), backgroundColor: AppTheme.success),
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

  Widget _buildCourtChipsForRound(int roundNum, List<MapEntry<String, int>> sortedCourts, Set<String> myCourts) {
    // 3コート以下ならチップバー不要
    if (sortedCourts.length <= 3) return const SizedBox();

    final filter = _selectedCourtFilter.containsKey(roundNum) ? _selectedCourtFilter[roundNum] : 'MY';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // 「全て」チップ
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: const Text('全て'),
                selected: filter == null,
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: filter == null ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                side: BorderSide(color: filter == null ? AppTheme.primaryColor : Colors.grey[300]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
                onSelected: (_) => setState(() { _selectedCourtFilter[roundNum] = null; _showOnlyMyCourts = false; }),
              ),
            ),
            // 「MY」チップ（自チームがある場合のみ）
            if (myCourts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('MY'),
                  selected: filter == 'MY',
                  selectedColor: AppTheme.accentColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: filter == 'MY' ? AppTheme.accentColor : AppTheme.accentColor.withValues(alpha: 0.7),
                  ),
                  side: BorderSide(color: filter == 'MY' ? AppTheme.accentColor : AppTheme.accentColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _selectedCourtFilter[roundNum] = filter == 'MY' ? null : 'MY';
                    _showOnlyMyCourts = false;
                  }),
                ),
              ),
            // 各コートチップ
            ...sortedCourts.map((court) {
              final courtId = court.key;
              final courtNum = court.value;
              final label = '${String.fromCharCode(64 + courtNum)}';
              final isSelected = filter == courtId;
              final isMyCourt = myCourts.contains(courtId);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label),
                    if (isMyCourt) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.star, size: 12, color: isSelected ? AppTheme.primaryColor : AppTheme.accentColor),
                    ],
                  ]),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                  side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _selectedCourtFilter[roundNum] = isSelected ? null : courtId;
                    _showOnlyMyCourts = false;
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundSection(String roundId, int roundNum, bool isOrganizer) {
    final isCollapsed = _collapsedRounds[roundNum] ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _collapsedRounds[roundNum] = !isCollapsed),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text('予選$roundNum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(width: 4),
              Icon(
                isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ],
          ),
        ),
      ),
      if (!isCollapsed)
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

          // 自分のチームが属するコートを特定
          final myCourts = <String>{};
          for (var entry in courtGroups.entries) {
            for (var m in entry.value) {
              final md = m.data() as Map<String, dynamic>;
              if (_myTeamIds.contains(md['teamAId'] ?? '') || _myTeamIds.contains(md['teamBId'] ?? '') ||
                  _myTeamIds.contains(md['refereeTeamId'] ?? '') || _myTeamIds.contains(md['subRefereeTeamId'] ?? '')) {
                myCourts.add(entry.key);
                break;
              }
            }
          }
          _myCourtIds = myCourts;

          final sortedCourts = courtGroups.entries.toList()..sort((a, b) {
            final aNum = (a.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            final bNum = (b.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            return (aNum as int).compareTo(bNum as int);
          });

          // コートチップ用データ
          final courtChipData = sortedCourts.map((e) {
            final num = (e.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
            return MapEntry(e.key, num as int);
          }).toList();

          final filter = _selectedCourtFilter.containsKey(roundNum) ? _selectedCourtFilter[roundNum] : 'MY';
          List<MapEntry<String, List<QueryDocumentSnapshot>>> filteredCourts;
          if (filter == 'MY') {
            filteredCourts = sortedCourts.where((court) => myCourts.contains(court.key)).toList();
          } else if (filter != null) {
            filteredCourts = sortedCourts.where((court) => court.key == filter).toList();
          } else if (_showOnlyMyCourts) {
            filteredCourts = sortedCourts.where((court) => myCourts.contains(court.key)).toList();
          } else {
            filteredCourts = sortedCourts;
          }

          return Column(children: [
            _buildCourtChipsForRound(roundNum, courtChipData, myCourts),
            ...filteredCourts.map((court) {
              final courtNum = (court.value.first.data() as Map<String, dynamic>)['courtNumber'] ?? 0;
              return _buildCourtCard(court.key, courtNum, court.value, roundId, isOrganizer);
            }),
          ]);
        },
      ),
      // Standings removed — now in dedicated 順位表 tab
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildCourtCard(String courtId, int courtNum, List<QueryDocumentSnapshot> matches, String roundId, bool isOrganizer) {
    // 自分のチームがこのコートに属しているか
    final isMyCourt = matches.any((m) {
      final md = m.data() as Map<String, dynamic>;
      return _myTeamIds.contains(md['teamAId'] ?? '') || _myTeamIds.contains(md['teamBId'] ?? '') ||
             _myTeamIds.contains(md['refereeTeamId'] ?? '') || _myTeamIds.contains(md['subRefereeTeamId'] ?? '');
    });
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMyCourt ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey[200]!, width: isMyCourt ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMyCourt ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.grey[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(Icons.sports_volleyball, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${String.fromCharCode(64 + courtNum)}コート', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (isMyCourt) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(4)),
                child: const Text('MY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
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
          final isMyMatch = _myTeamIds.contains(m['teamAId'] ?? '') || _myTeamIds.contains(m['teamBId'] ?? '') || isReferee;
          final canInput = isOrganizer || isMyMatch;
          final isCompleted = status == 'completed';
          final isNextToInput = !isCompleted && prevDone && isMyMatch;
          return InkWell(
            onTap: () {
              if (isCompleted && !isOrganizer) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("この試合は確定済みです。編集は大会主催者のみ可能です"), backgroundColor: Colors.orange));
                return;
              }
              if (!canInput) return;
              if (!prevDone) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("前の試合が完了してから入力してください"), backgroundColor: Colors.orange));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreInputScreen(
                tournamentId: _tournamentId, matchId: mDoc.id, roundId: roundId, isOrganizer: isOrganizer)));
            },
            child: Container(
            color: isNextToInput ? AppTheme.primaryColor.withValues(alpha: 0.06) : null,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 8, bottom: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text("第$matchOrder試合", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isNextToInput ? AppTheme.primaryColor : AppTheme.textSecondary)),
                    if (isNextToInput) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(4)),
                        child: const Text('入力待ち', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ]),
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
                      color: status == 'completed' ? AppTheme.success.withValues(alpha:0.1) : Colors.grey[100],
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
            ])),
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
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha:0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
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
                color: isMyTeam ? Colors.red.withValues(alpha:0.08) : null,
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
    final rankRange = bData['rankRange'] as String? ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
          const SizedBox(width: 8),
          Text('${bData['bracketName'] ?? '順位決定'}リーグ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
          if (rankRange.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(rankRange, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[800])),
            ),
          ],
        ]),
      ),
      StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tournaments').doc(_tournamentId)
            .collection('brackets').doc(bracketId)
            .collection('matches').orderBy('matchNumber').snapshots(),
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) return const SizedBox();

          // Group matches by round
          final roundOrder = ['qf', 'sf_winner', 'sf_loser', 'semi', 'final_1st', 'final_3rd', 'final_5th', 'final_7th', 'final', 'round-robin'];
          final roundLabels = {
            'qf': '準々決勝', 'sf_winner': '準決勝（勝者）', 'sf_loser': '準決勝（敗者）',
            'semi': '準決勝', 'final_1st': '決勝（1-2位）', 'final_3rd': '3位決定戦',
            'final_5th': '5位決定戦', 'final_7th': '7位決定戦', 'final': '決勝', 'round-robin': '総当たり',
          };

          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (var doc in matchSnap.data!.docs) {
            final round = (doc.data() as Map<String, dynamic>)['round'] as String? ?? '';
            grouped.putIfAbsent(round, () => []);
            grouped[round]!.add(doc);
          }

          final sortedRounds = grouped.keys.toList()
            ..sort((a, b) => (roundOrder.indexOf(a) == -1 ? 99 : roundOrder.indexOf(a))
                .compareTo(roundOrder.indexOf(b) == -1 ? 99 : roundOrder.indexOf(b)));

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sortedRounds.map((round) {
            final matches = grouped[round]!;
            final label = roundLabels[round] ?? round;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4),
                child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber[800])),
              ),
              ...matches.map((mDoc) {
                final m = mDoc.data() as Map<String, dynamic>;
                final status = m['status'] ?? 'pending';
                final result = m['result'] as Map<String, dynamic>? ?? {};
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha:0.3))),
                  child: InkWell(
                    onTap: (isOrganizer && status != 'waiting') ? () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreInputScreen(
                        tournamentId: _tournamentId, matchId: mDoc.id, roundId: '', isBracket: true, bracketId: bracketId, isOrganizer: isOrganizer)));
                    } : null,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(m['teamAName'] ?? '', style: TextStyle(fontSize: 16,
                            fontWeight: status == 'completed' && result['winner'] == m['teamAId'] ? FontWeight.bold : FontWeight.normal),
                            textAlign: TextAlign.right)),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'completed' ? Colors.amber.withValues(alpha:0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            status == 'completed' ? '${result['setsA'] ?? 0}-${result['setsB'] ?? 0}' : (status == 'waiting' ? '待機中' : 'vs'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: status == 'completed' ? Colors.amber[800] : AppTheme.textSecondary)),
                        ),
                        Expanded(flex: 3, child: Text(m['teamBName'] ?? '', style: TextStyle(fontSize: 16,
                            fontWeight: status == 'completed' && result['winner'] == m['teamBId'] ? FontWeight.bold : FontWeight.normal))),
                      ]),
                    ),
                  ),
                );
              }),
            ]);
          }).toList());
        },
      ),
    ]);
  }

  Future<void> _generateMatches(int roundNumber) async {
    String assignmentMode = 'snake';

    // 予選2の場合、コート割り振り方法を選択
    if (roundNumber >= 2) {
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String mode = 'snake';
          return StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('予選2 コート割り振り', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              RadioListTile<String>(
                value: 'snake', groupValue: mode, activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: const Text('実力均等配置', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('予選1の順位をもとに、各コートの実力が均等になるように配置します', style: TextStyle(fontSize: 12)),
                onChanged: (v) => setDialogState(() => mode = v!),
              ),
              const SizedBox(height: 4),
              RadioListTile<String>(
                value: 'random', groupValue: mode, activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: const Text('完全ランダム', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('ランダムに割り振ります（予選1で同じコートだったチームはなるべく別コートに配置）', style: TextStyle(fontSize: 12)),
                onChanged: (v) => setDialogState(() => mode = v!),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, mode),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('生成'),
              ),
            ],
          ));
        },
      );
      if (selected == null) return;
      assignmentMode = selected;
    }

    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      await MatchGenerator().generatePreliminary(tournamentId: _tournamentId, roundNumber: roundNumber, assignmentMode: assignmentMode);
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
  Future<void> _deleteEntryTeams() async {
    // エントリー済みチームを取得
    final entriesSnap = await _firestore.collection('tournaments').doc(_tournamentId).collection('entries').get();
    if (entriesSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エントリーチームがありません'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    final entries = entriesSnap.docs.map((d) {
      final data = d.data();
      return {'docId': d.id, 'teamName': data['teamName'] ?? '', 'leaderName': data['leaderName'] ?? '', 'memberCount': data['memberCount'] ?? 0};
    }).toList();

    if (!mounted) return;
    final selectedIds = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.delete_sweep, color: AppTheme.error),
            const SizedBox(width: 8),
            const Text('チームを削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(children: [
              Row(children: [
                Text('${selectedIds.length}件選択中', style: TextStyle(fontSize: 13, color: selectedIds.isNotEmpty ? AppTheme.error : AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setDialogState(() {
                    if (selectedIds.length == entries.length) {
                      selectedIds.clear();
                    } else {
                      selectedIds.addAll(entries.map((e) => e['docId'] as String));
                    }
                  }),
                  child: Text(selectedIds.length == entries.length ? '全解除' : '全選択', style: const TextStyle(fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final docId = e['docId'] as String;
                    final isSelected = selectedIds.contains(docId);
                    return CheckboxListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      value: isSelected,
                      activeColor: AppTheme.error,
                      onChanged: (v) => setDialogState(() {
                        if (v == true) { selectedIds.add(docId); } else { selectedIds.remove(docId); }
                      }),
                      secondary: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected ? AppTheme.error.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? AppTheme.error : AppTheme.primaryColor)),
                      ),
                      title: Text(e['teamName'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.error : null)),
                      subtitle: Text('チームキャプテン: ${e['leaderName']} / ${e['memberCount']}人', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    );
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
              child: Text('${selectedIds.length}件削除する'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedIds.isEmpty) return;

    try {
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));
      final batch = _firestore.batch();
      for (final docId in selectedIds) {
        batch.delete(_firestore.collection('tournaments').doc(_tournamentId).collection('entries').doc(docId));
      }
      batch.update(_firestore.collection('tournaments').doc(_tournamentId), {'currentTeams': FieldValue.increment(-selectedIds.length)});
      await batch.commit();
      await _loadMyTeams();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selectedIds.length}チームを削除しました'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
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
            const SnackBar(content: Text('順位決定戦を生成しました！'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
  void _showMemberList(String teamName, Map<String, dynamic> memberNames, String leaderName) {
    final members = memberNames.entries.toList();
    // leaderNameと一致するメンバーを先頭に並べ替え
    members.sort((a, b) {
      final aIsLeader = a.value?.toString() == leaderName;
      final bIsLeader = b.value?.toString() == leaderName;
      if (aIsLeader && !bIsLeader) return -1;
      if (!aIsLeader && bIsLeader) return 1;
      return 0;
    });

    // メンバーのアバターURLを取得
    final memberAvatars = <String, String>{};
    Future<void> loadAvatars() async {
      for (final entry in members) {
        final uid = entry.key;
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          memberAvatars[uid] = (userDoc.data()?['avatarUrl'] ?? '').toString();
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder(
        future: loadAvatars(),
        builder: (ctx, snapshot) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${members.length}人のメンバー', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ...members.asMap().entries.map((entry) {
                final uid = entry.value.key;
                final name = entry.value.value?.toString() ?? '名前なし';
                final isFirst = entry.key == 0;
                final avatarUrl = memberAvatars[uid] ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: avatarUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                          child: Text(name.isNotEmpty ? name[0] : '?',
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                  title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: isFirst ? Text('チームキャプテン', style: TextStyle(fontSize: 12, color: AppTheme.accentColor)) : null,
                  trailing: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: uid),
                      ));
                    },
                    child: Icon(Icons.chevron_right, color: AppTheme.textHint),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: uid),
                    ));
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).collection('entries').snapshots(),
      builder: (context, entriesSnap) {
        if (!entriesSnap.hasData) return const Center(child: CircularProgressIndicator());
        final entries = entriesSnap.data?.docs ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.groups_outlined, size: 64, color: AppTheme.textHint),
              const SizedBox(height: 16),
              const Text('まだエントリーはありません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
            ]),
          );
        }

        // チェックイン状況をリアルタイム取得
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('tournaments').doc(_tournamentId).collection('checkIns').snapshots(),
          builder: (context, checkInSnap) {
            final checkedInTeamIds = <String>{};
            if (checkInSnap.hasData) {
              for (final doc in checkInSnap.data!.docs) {
                checkedInTeamIds.add((doc.data() as Map<String, dynamic>)['teamId'] ?? '');
              }
            }
            final checkedCount = entries.where((e) => checkedInTeamIds.contains((e.data() as Map<String, dynamic>)['teamId'])).length;

            // 自分のチームを先頭にソート
            final sortedEntries = List<QueryDocumentSnapshot>.from(entries);
            sortedEntries.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aIsMyTeam = _myTeamIds.contains(aData['teamId'] ?? '');
              final bIsMyTeam = _myTeamIds.contains(bData['teamId'] ?? '');
              if (aIsMyTeam && !bIsMyTeam) return -1;
              if (!aIsMyTeam && bIsMyTeam) return 1;
              return 0;
            });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ヘッダー: エントリー数 + 受付状況
                Row(children: [
                  Text('エントリー済み ${entries.length}チーム',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (checkedInTeamIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: checkedCount == entries.length ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.how_to_reg, size: 14,
                          color: checkedCount == entries.length ? AppTheme.success : AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text('$checkedCount/${entries.length}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: checkedCount == entries.length ? AppTheme.success : AppTheme.primaryColor)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),
                ...sortedEntries.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final teamId = data['teamId'] ?? '';
                  final teamName = data['teamName'] ?? 'チーム';
                  final leader = data['leaderName'] ?? '';
                  final memberUids = (data['memberUids'] as List<dynamic>?) ?? [];
                  final memberNames = (data['memberNames'] as Map<String, dynamic>?) ?? {};
                  final isMyTeam = _myTeamIds.contains(teamId);
                  final isCheckedIn = checkedInTeamIds.contains(teamId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: isMyTeam ? () => _showMemberList(teamName.toString(), memberNames, leader.toString()) : null,
                      child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMyTeam ? Colors.red.withValues(alpha:0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isMyTeam ? Colors.red.withValues(alpha:0.3) : Colors.grey[200]!),
                      ),
                      child: Row(children: [
                        // アバター：チェックイン済みの場合は緑のチェックマーク付き
                        Stack(
                          children: [
                            CircleAvatar(radius: 20, backgroundColor: isMyTeam ? Colors.red.withValues(alpha:0.12) : AppTheme.primaryColor.withValues(alpha:0.12),
                                child: Text(teamName.toString().isNotEmpty ? teamName.toString()[0] : '?',
                                    style: TextStyle(color: isMyTeam ? Colors.red : AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                            if (isCheckedIn)
                              Positioned(right: 0, bottom: 0,
                                child: Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(teamName.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isMyTeam ? Colors.red : AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('チームキャプテン: $leader / ${memberUids.length}人', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              if (isCheckedIn) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text('受付済', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
                                ),
                              ],
                            ]),
                          ]),
                        ),
                        if (isMyTeam) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text('自分', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
                        ] else if (!isCheckedIn && checkedInTeamIds.isNotEmpty) ...[
                          Text('未到着', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
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
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.image, color: AppTheme.primaryColor, size: 24),
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null && mounted) setState(() => _selectedBoardImage = picked);
                },
              ),
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _submitTimelinePost(uid)),
              ),
            ],
          ),
        ),
        // 画像プレビュー
        if (_selectedBoardImage != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FutureBuilder<Uint8List>(
                    future: _selectedBoardImage!.readAsBytes(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox(height: 100);
                      return Image.memory(snap.data!, height: 100, width: double.infinity, fit: BoxFit.cover);
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedBoardImage = null),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        // 主催者向け: お知らせ送信ボタン
        if (!_isBoardTeam && widget.tournament['organizerId'] == FirebaseAuth.instance.currentUser?.uid)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: GestureDetector(
              onTap: () => _showAnnouncementDialog(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign, size: 18, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Text('全参加者にお知らせを送信', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
                  ],
                ),
              ),
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
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                  final imageUrl = data['imageUrl'] as String? ?? '';
                  final isOrganizer = data['isOrganizer'] == true;
                  final isPinned = data['pinned'] == true;
                  final isAnnouncement = data['isAnnouncement'] == true;
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
                      color: isAnnouncement ? AppTheme.accentColor.withValues(alpha: 0.04) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isAnnouncement ? Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)) : null,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAnnouncement)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.campaign, size: 14, color: AppTheme.accentColor),
                                const SizedBox(width: 4),
                                Text('お知らせ', style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          )
                        else if (isPinned)
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
                              child: Text('大会主催者', style: TextStyle(fontSize: 10, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          const Spacer(),
                          Text(timeAgo, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                        ]),
                        const SizedBox(height: 8),
                        if (text.toString().isNotEmpty)
                          Text(text.toString(), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
                        if (imageUrl.isNotEmpty) ...[
                          if (text.toString().isNotEmpty) const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showFullBoardImage(imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return Container(height: 180, color: Colors.grey[100],
                                        child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2)));
                                  },
                                  errorBuilder: (_, __, ___) => const SizedBox()),
                            ),
                          ),
                        ],
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
    final hasImage = _selectedBoardImage != null;
    if (text.isEmpty && !hasImage) return;
    if (_tournamentId.isEmpty) return;

    // ローディング表示
    if (hasImage && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    try {
      String imageUrl = '';
      if (hasImage) {
        final bytes = await _selectedBoardImage!.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedBoardImage!.name}';
        final ref = FirebaseStorage.instance
            .ref().child('tournament_board').child(_tournamentId).child(fileName);
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      }

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final nickname = userData['nickname'] ?? '匿名';
      final avatar = userData['avatarUrl'] ?? '';

      final postData = <String, dynamic>{
        'authorId': uid, 'authorName': nickname, 'authorAvatar': avatar,
        'text': text, 'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl.isNotEmpty) postData['imageUrl'] = imageUrl;

      if (_isBoardTeam && _myEntryTeamId.isNotEmpty) {
        await _firestore.collection('tournaments').doc(_tournamentId)
            .collection('team_board').doc(_myEntryTeamId).collection('posts').add(postData);
      } else {
        final tournamentDoc = await _firestore.collection('tournaments').doc(_tournamentId).get();
        final tournamentData = tournamentDoc.data() ?? {};
        final isOrganizer = tournamentData['organizerId'] == uid;

        postData.addAll({'isOrganizer': isOrganizer, 'pinned': false, 'likesCount': 0});
        await _firestore.collection('tournaments').doc(_tournamentId).collection('timeline').add(postData);
      }

      _postController.clear();
      setState(() => _selectedBoardImage = null);
      FocusScope.of(context).unfocus();
      if (hasImage && mounted) Navigator.pop(context); // ローディング閉じる
    } catch (e) {
      if (hasImage && mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投稿に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── 掲示板に画像を投稿 ──
  Future<void> _pickAndSendBoardImage(String uid) async {
    if (_tournamentId.isEmpty) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;

      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );

      final bytes = await picked.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('tournament_board')
          .child(_tournamentId)
          .child(fileName);

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final nickname = userData['nickname'] ?? '匿名';
      final avatar = userData['avatarUrl'] ?? '';

      if (_isBoardTeam && _myEntryTeamId.isNotEmpty) {
        await _firestore.collection('tournaments').doc(_tournamentId)
            .collection('team_board').doc(_myEntryTeamId).collection('posts').add({
          'authorId': uid, 'authorName': nickname, 'authorAvatar': avatar,
          'text': '', 'imageUrl': downloadUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final tournamentDoc = await _firestore.collection('tournaments').doc(_tournamentId).get();
        final tournamentData = tournamentDoc.data() ?? {};
        final isOrganizer = tournamentData['organizerId'] == uid;

        await _firestore.collection('tournaments').doc(_tournamentId).collection('timeline').add({
          'authorId': uid, 'authorName': nickname, 'authorAvatar': avatar,
          'text': '', 'imageUrl': downloadUrl,
          'isOrganizer': isOrganizer, 'pinned': false,
          'likesCount': 0, 'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context); // ローディング閉じる
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ローディング閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の送信に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── 掲示板画像フルスクリーン ──
  void _showFullBoardImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━ フォトギャラリータブ ━━━
  Widget _buildPhotoGalleryTab() {
    if (_tournamentId.isEmpty) return const Center(child: Text('大会IDが見つかりません'));
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        // 写真アップロードボタン
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: InkWell(
            onTap: () => _uploadGalleryPhoto(uid),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text('大会の写真をアップロード', style: TextStyle(
                    fontSize: 14, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
        // 写真グリッド
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tournaments').doc(_tournamentId)
                .collection('photos').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }
              final photos = snapshot.data?.docs ?? [];

              if (photos.isEmpty) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 56, color: AppTheme.textHint),
                    const SizedBox(height: 12),
                    const Text('まだ写真はありません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    const Text('大会の思い出を共有しましょう！', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  ],
                ));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photoDoc = photos[index];
                  final data = photoDoc.data() as Map<String, dynamic>;
                  final imageUrl = (data['imageUrl'] as String?) ?? '';
                  final uploaderName = (data['uploaderName'] as String?) ?? '';
                  final uploadedBy = (data['uploadedBy'] as String?) ?? '';
                  return GestureDetector(
                    onTap: () => _showGalleryPhoto(imageUrl, uploaderName, data['createdAt'] as Timestamp?),
                    onLongPress: uploadedBy == uid
                        ? () => _confirmDeleteGalleryPhoto(photoDoc.id)
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl, fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(color: Colors.grey[100],
                              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2)));
                        },
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[100],
                            child: const Icon(Icons.broken_image, color: AppTheme.textHint)),
                      ),
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

  // ── 写真ギャラリーにアップロード ──
  Future<void> _uploadGalleryPhoto(String uid) async {
    if (_tournamentId.isEmpty) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );

      final bytes = await picked.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('tournament_photos')
          .child(_tournamentId)
          .child(fileName);

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final uploaderName = (userDoc.data()?['nickname'] as String?) ?? 'ユーザー';

      await _firestore.collection('tournaments').doc(_tournamentId).collection('photos').add({
        'imageUrl': downloadUrl,
        'uploadedBy': uid,
        'uploaderName': uploaderName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // ローディング閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真をアップロードしました'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アップロードに失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── ギャラリー写真を削除 ──
  void _confirmDeleteGalleryPhoto(String photoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('写真を削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('この写真を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('tournaments').doc(_tournamentId)
                  .collection('photos').doc(photoId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('写真を削除しました'), backgroundColor: AppTheme.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ── ギャラリー写真フルスクリーン ──
  void _showGalleryPhoto(String url, String uploaderName, Timestamp? createdAt) {
    String timeText = '';
    if (createdAt != null) {
      final date = createdAt.toDate();
      timeText = '${date.year}/${date.month}/${date.day}';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 閉じるボタン
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 画像
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            // 投稿者情報
            if (uploaderName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$uploaderName  $timeText',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                        color: AppTheme.primaryColor.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha:0.15)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((widget.tournament['name'] ?? widget.tournament['title'] ?? '') as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        Text((widget.tournament['date'] ?? '') as String,
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
                                    : CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor.withValues(alpha:0.1),
                                        child: Text(fName.toString().isNotEmpty ? fName.toString()[0] : '?', style: TextStyle(color: AppTheme.primaryColor))),
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
                    const SizedBox(height: 8),
                    Text(
                      selectedMembers.isEmpty
                          ? '自分＋メンバー3人以上を選択してください（4人以上必要）'
                          : '${selectedMembers.length + 1}人（自分＋${selectedMembers.length}人選択中）${selectedMembers.length < 3 ? " ※あと${3 - selectedMembers.length}人必要" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedMembers.length < 3 ? AppTheme.textHint : AppTheme.primaryColor,
                      ),
                    ),
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
                          // 自分 + 選択メンバーで4人以上必要
                          if (selectedMembers.length < 3) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('メンバーは自分を含めて4人以上必要です'), backgroundColor: AppTheme.warning));
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
                Text((widget.tournament['name'] ?? widget.tournament['title'] ?? '') as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text((widget.tournament['date'] ?? '') as String, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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

    // エントリー重複チェック（enteredBy OR memberUidsに含まれる場合）
    final allEntries = await _firestore
        .collection('tournaments').doc(_tournamentId)
        .collection('entries').get();
    final alreadyEntered = allEntries.docs.any((d) {
      final data = d.data();
      if (data['enteredBy'] == uid) return true;
      final memberUids = data['memberUids'];
      if (memberUids is List && memberUids.contains(uid)) return true;
      return false;
    });

    if (alreadyEntered) {
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

  Widget _buildOrganizerOnlyBottom(Map<String, dynamic> t) {
    final status = t['status'] as String? ?? '';
    final isRecruiting = status == '募集中' || status == '満員';
    final notEntered = _myEntryTeamId.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: isRecruiting && notEntered
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text('まだエントリーしていません', style: TextStyle(fontSize: 13, color: AppTheme.warning, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEntrySheet(context),
                    icon: const Icon(Icons.how_to_reg, size: 18),
                    label: const Text('エントリー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrganizerMenuSheet(t),
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('大会主催者メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ])
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showOrganizerMenuSheet(t),
                icon: const Icon(Icons.admin_panel_settings, size: 20),
                label: const Text('大会主催者メニュー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
    );
  }

  // ━━━ 受付メニュー ━━━
  void _showReceptionMenuSheet(Map<String, dynamic> tournData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.how_to_reg, size: 22, color: AppTheme.success),
              ),
              const SizedBox(width: 12),
              const Text('受付メニュー', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: Colors.grey[200]),
          ),
          // 受付状況サマリー
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tournaments').doc(_tournamentId).collection('entries').snapshots(),
            builder: (_, entriesSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('tournaments').doc(_tournamentId).collection('checkIns').snapshots(),
                builder: (_, checkInSnap) {
                  final total = entriesSnap.data?.docs.length ?? 0;
                  final checked = checkInSnap.data?.docs.length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        SizedBox(
                          width: 44, height: 44,
                          child: CircularProgressIndicator(
                            value: total > 0 ? checked / total : 0,
                            strokeWidth: 5,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(checked >= total && total > 0 ? AppTheme.success : AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$checked / $total チーム到着', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(checked >= total && total > 0 ? '全チーム到着済み' : '受付中...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ]),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 4),
          _menuTile(ctx, Icons.qr_code, '大会QRコードを表示', 'スマホ・PC・タブレットで表示、または印刷', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')));
          }, color: AppTheme.primaryColor),
          _menuTile(ctx, Icons.checklist, '手動チェックイン', 'リストからチームを手動でチェックイン', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')));
          }, color: AppTheme.success),
          _menuTile(ctx, Icons.payment, '参加費の確認', '各チームの入金状況を確認', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => TournamentFinanceScreen(tournamentId: _tournamentId, tournamentData: tournData)));
          }, color: AppTheme.accentColor),
        ]),
      ),
    );
  }

  void _showOrganizerMenuSheet(Map<String, dynamic> tournData) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _OrganizerMenuScreen(
        tournData: tournData,
        tournamentId: _tournamentId,
        onEditTournament: () => _showEditTournamentSheet(tournData),
        onStatusChange: () => _showStatusDialog(tournData['status'] ?? '準備中'),
        onSelfEntry: () => _showEntrySheet(context),
        onCheckIn: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? ''))),
        onCsvMenu: _showCsvImportMenu,
        onDeleteTeams: _deleteEntryTeams,
        onFinance: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentFinanceScreen(tournamentId: _tournamentId, tournamentData: tournData))),
        onEditors: _showEditorsSheet,
        onAnnouncement: _showAnnouncementDialog,
        onGenerateRound2: () => _generateMatches(2),
        onGenerateFinals: _generateFinals,
        onReset: _resetRounds,
        onEndTournament: _showEndTournamentDialog,
        onSaveTemplate: () => _saveAsTemplate(tournData),
        onDelete: () => _showDeleteDialog(tournData['title'] ?? ''),
      ),
    ));
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _menuTile(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = AppTheme.primaryColor, bool isDestructive = false}) {
    final c = isDestructive ? AppTheme.error : color;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: c),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDestructive ? AppTheme.error : AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
      onTap: () { Navigator.pop(ctx); onTap(); },
    );
  }

  bool _isTournamentToday() {
    try {
      final dateStr = widget.tournament['date'] as String? ?? '';
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return d == today;
      }
    } catch (_) {}
    return false;
  }

  void _showCheckInOptions() {
    final teamName = _myTeamIds.isNotEmpty ? _myTeamIds.first : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('チェックイン', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('チェックイン方法を選んでください', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showMyTeamQR(_myEntryTeamId, '');
                },
                icon: const Icon(Icons.qr_code, size: 22),
                label: const Text('QRコードを見せる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CheckInScreen(
                      tournamentId: _tournamentId,
                      tournamentName: widget.tournament['name'] as String? ?? '',
                    ),
                  ));
                },
                icon: const Icon(Icons.qr_code_scanner, size: 22),
                label: const Text('QRコードを読み取る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('tournaments').doc(_tournamentId).snapshots(),
      builder: (context, snap) {
        final live = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic>? ?? {} : <String, dynamic>{};
        final t = live.isNotEmpty ? live : widget.tournament;
        final status = t['status'] as String? ?? '準備中';
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final editors = List<String>.from(t['editors'] ?? []);
        final isOrganizer = t['organizerId'] == uid || editors.contains(uid);

        // 主催者の場合
        if (isOrganizer) {
          if (status != '開催中') {
            // 当日（開催中）以外 → 主催者メニューのみ
            return _buildOrganizerOnlyBottom(t);
          }
          // 当日（開催中） → チェックイン状況を確認して受付メニュー＋主催者メニュー
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tournaments').doc(_tournamentId).collection('entries').snapshots(),
            builder: (context, entriesSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('tournaments').doc(_tournamentId).collection('checkIns').snapshots(),
                builder: (context, checkInSnap) {
                  final totalEntries = entriesSnap.data?.docs.length ?? 0;
                  final checkedIn = checkInSnap.data?.docs.length ?? 0;
                  final allCheckedIn = totalEntries > 0 && checkedIn >= totalEntries;

                  if (allCheckedIn) {
                    // 全チーム受付完了 → 主催者メニューのみ
                    return _buildOrganizerOnlyBottom(t);
                  }

                  // 受付中 → 受付メニュー＋主催者メニューの2ボタン
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // 受付状況バー
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(Icons.how_to_reg, size: 16, color: AppTheme.success),
                          const SizedBox(width: 8),
                          Text('受付状況: $checkedIn/$totalEntries チーム', style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${totalEntries > 0 ? (checkedIn * 100 ~/ totalEntries) : 0}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      // 2ボタン
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showReceptionMenuSheet(t),
                            icon: const Icon(Icons.how_to_reg, size: 18),
                            label: const Text('受付メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showOrganizerMenuSheet(t),
                            icon: const Icon(Icons.admin_panel_settings, size: 18),
                            label: const Text('大会主催者メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  );
                },
              );
            },
          );
        }

        final isEnded = status == '開催済み' || status == '開催中' || status == '決勝中' || status == '順位決定中' || status == '終了' || status.contains('完了');
        if (isEnded) return const SizedBox.shrink();

        // 大会当日 & エントリー済み → 自チームのチェックイン完了まで表示
        if (_isTournamentToday() && _myEntryTeamId.isNotEmpty) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tournaments').doc(_tournamentId).collection('checkIns').snapshots(),
            builder: (context, checkInSnap) {
              final checkInDocs = checkInSnap.data?.docs ?? [];
              final myTeamCheckedIn = checkInDocs.any((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['teamId'] == _myEntryTeamId;
              });
              // 自チームのチェックイン完了 → ボタン非表示
              if (myTeamCheckedIn) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showCheckInOptions,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('チェックイン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              );
            },
          );
        }

        final currentTeams = t['currentTeams'] is int ? t['currentTeams'] as int : 0;
        final maxTeams = t['maxTeams'] is int ? t['maxTeams'] as int : 0;
        final isFull = maxTeams > 0 && currentTeams >= maxTeams;

        // 満員の場合はキャンセル待ちUI表示
        if (isFull || status == '満員') {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Text('現在満員です ($currentTeams/$maxTeamsチーム)', style: TextStyle(fontSize: 13, color: AppTheme.warning, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showWaitlistSheet(context),
                    icon: const Icon(Icons.hourglass_empty, size: 18),
                    label: const Text('キャンセル待ちに登録', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      side: const BorderSide(color: AppTheme.warning, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final isDisabled = false;
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
                        const SnackBar(content: Text('大会主催者をフォローしました！エントリーできます'), backgroundColor: AppTheme.success),
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
      },
    );
  }

  // ━━━ キャンセル待ち ━━━
  void _showWaitlistSheet(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final teamNameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.hourglass_empty, color: AppTheme.warning, size: 22),
              const SizedBox(width: 8),
              const Text('キャンセル待ち登録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((widget.tournament['name'] ?? widget.tournament['title'] ?? '') as String,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('空きが出た場合に通知が届きます', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('チーム名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: teamNameCtrl,
              decoration: InputDecoration(
                hintText: 'チーム名を入力',
                filled: true, fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // 現在のキャンセル待ち状況
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('tournaments').doc(_tournamentId)
                  .collection('waitlist').orderBy('createdAt').snapshots(),
              builder: (context, snap) {
                final waitlist = snap.data?.docs ?? [];
                final alreadyWaiting = waitlist.any((d) => (d.data() as Map<String, dynamic>)['userId'] == uid);
                if (alreadyWaiting) {
                  final myPosition = waitlist.indexWhere((d) => (d.data() as Map<String, dynamic>)['userId'] == uid) + 1;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 32),
                      const SizedBox(height: 8),
                      Text('キャンセル待ち登録済み', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.success)),
                      const SizedBox(height: 4),
                      Text('現在$myPosition番目 / ${waitlist.length}人待ち', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final myDoc = waitlist.firstWhere((d) => (d.data() as Map<String, dynamic>)['userId'] == uid);
                            await _firestore.collection('tournaments').doc(_tournamentId)
                                .collection('waitlist').doc(myDoc.id).delete();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('キャンセル待ちを取り消しました'), backgroundColor: AppTheme.warning),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                          ),
                          child: const Text('キャンセル待ちを取り消す'),
                        ),
                      ),
                    ]),
                  );
                }

                return Column(children: [
                  if (waitlist.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('現在${waitlist.length}チームがキャンセル待ち中', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final teamName = teamNameCtrl.text.trim();
                        if (teamName.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('チーム名を入力してください'), backgroundColor: AppTheme.warning),
                          );
                          return;
                        }

                        final userDoc = await _firestore.collection('users').doc(uid).get();
                        final nickname = userDoc.data()?['nickname'] ?? '名前なし';

                        await _firestore.collection('tournaments').doc(_tournamentId)
                            .collection('waitlist').add({
                          'userId': uid,
                          'userName': nickname,
                          'teamName': teamName,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('キャンセル待ちに登録しました（${waitlist.length + 1}番目）'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.hourglass_empty, size: 18),
                      label: const Text('キャンセル待ちに登録', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]);
              },
            ),
            const SizedBox(height: 8),
          ]),
        );
      },
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
                        color: AppTheme.primaryColor.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha:0.15)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((widget.tournament['name'] ?? widget.tournament['title'] ?? '') as String,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 4),
                        Text((widget.tournament['date'] ?? '') as String,
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
  String _buildShareUrl() {
    final base = Uri.base.origin;
    return '$base/?t=$_tournamentId';
  }

  void _showShareOptions(BuildContext context) {
    final tournamentName = widget.tournament['name'] ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('\u5927\u4f1a\u3092\u30b7\u30a7\u30a2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildShareOption(
                icon: Icons.chat_bubble,
                label: 'LINE',
                color: const Color(0xFF06C755),
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = _buildShareUrl();
                  final text = Uri.encodeComponent('$tournamentName\n$url');
                  final lineUrl = 'https://line.me/R/share?text=$text';
                  final uri = Uri.parse(lineUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildShareOption(
                icon: Icons.link,
                label: 'URL\u30b3\u30d4\u30fc',
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pop(ctx);
                  final url = _buildShareUrl();
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('URL\u3092\u30b3\u30d4\u30fc\u3057\u307e\u3057\u305f'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showPdfSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('PDF\u30c0\u30a6\u30f3\u30ed\u30fc\u30c9', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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

  Widget _buildAddressRow(String address) {
    return GestureDetector(
      onTap: () {
        final encoded = Uri.encodeComponent(address);
        final uri = Uri.parse('https://www.google.com/maps/search/$encoded');
        launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.map, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('住所', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(address, style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
          ])),
          const Icon(Icons.open_in_new, size: 14, color: AppTheme.primaryColor),
        ]),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey[100]);

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _buildTimelineRow(String time, String label, IconData icon, {bool isLast = false}) {
    const double dotSize = 10;
    const double rowMinHeight = 36;
    return IntrinsicHeight(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: rowMinHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 時刻（ドットと中央揃え）
            SizedBox(
              width: 56,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
              ),
            ),
            // タイムライン（ドット＋縦線）
            SizedBox(
              width: dotSize,
              child: Column(children: [
                const SizedBox(height: 6),
                Container(
                  width: dotSize, height: dotSize,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppTheme.primaryColor.withValues(alpha: 0.15))),
              ]),
            ),
            const SizedBox(width: 12),
            // ラベル
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(icon, size: 16, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value, {String? subtitle, VoidCallback? onSubtitleTap, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
                if (subtitle != null)
                  GestureDetector(
                    onTap: onSubtitleTap,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, decoration: onSubtitleTap != null ? TextDecoration.underline : null))),
                        if (onSubtitleTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new, size: 12, color: AppTheme.primaryColor),
                        ],
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSectionCard(String title, IconData icon, Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        // ヘッダー
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
        // テーブル行
        ...rows,
      ]),
    );
  }

  Widget _buildRuleTableRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
      ]),
    );
  }

  Widget _buildTierInfoRow(int tierCount, int maxTeams) {
    final names = _getTierDisplayNames(tierCount);
    final teamsPerTier = maxTeams > 0 ? (maxTeams / tierCount).ceil() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('区分', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ...List.generate(names.length, (i) {
            final rankStart = i * teamsPerTier + 1;
            final rankEnd = ((i + 1) * teamsPerTier).clamp(1, maxTeams > 0 ? maxTeams : (i + 1) * teamsPerTier);
            final rankText = maxTeams > 0 ? '（予選$rankStart〜$rankEnd位）' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _tierColor(i, names.length).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(names[i],
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _tierColor(i, names.length)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${names[i]}リーグ$rankText',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '予選リーグの順位をもとに$tierCount区分に分かれてトーナメント戦を行います',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getTierDisplayNames(int count) {
    switch (count) {
      case 1: return ['リーグ'];
      case 2: return ['上', '下'];
      case 3: return ['上', '中', '下'];
      case 4: return ['上', '中上', '中下', '下'];
      case 5: return ['上', '中上', '中', '中下', '下'];
      case 6: return ['上', '中上', '中', '中下', '下', 'エンジョイ'];
      default:
        final names = ['上', '中上', '中', '中下', '下'];
        for (int i = 5; i < count; i++) names.add('第${i + 1}');
        return names;
    }
  }

  Color _tierColor(int index, int total) {
    if (index == 0) return Colors.amber[700]!;
    if (index == total - 1) return AppTheme.primaryColor;
    return AppTheme.accentColor;
  }

  Widget _buildScoringTable(Map<String, dynamic> prelim, Map<String, dynamic> scoring) {
    final rounds = prelim['rounds'] ?? 1;
    final hasRound2 = rounds == 2 && scoring['round2'] != null;
    // 2ラウンド形式: scoring内もround1/round2に分かれている
    final s1 = hasRound2 ? (scoring['round1'] as Map<String, dynamic>? ?? scoring) : scoring;
    final s2 = hasRound2 ? (scoring['round2'] as Map<String, dynamic>?) : null;
    // sets も round1 キーから取得
    final r1Data = rounds == 2 ? (prelim['round1'] as Map<String, dynamic>? ?? {}) : prelim;
    final sets = r1Data['sets'] ?? 2;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        // ヘッダー
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(children: [
            Icon(Icons.emoji_events, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 6),
            Text('勝ち点制', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentColor)),
          ]),
        ),
        // テーブルヘッダー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.grey[50]),
          child: Row(children: [
            Expanded(flex: 3, child: Text('結果', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            if (hasRound2) ...[
              Expanded(flex: 2, child: Text('R1', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
              Expanded(flex: 2, child: Text('R2', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            ] else
              Expanded(flex: 2, child: Text('勝ち点', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
          ]),
        ),
        ..._buildScoringTableRows(sets, s1, s2),
      ]),
    );
  }

  List<Widget> _buildScoringTableRows(int sets, Map<String, dynamic> s1, Map<String, dynamic>? s2) {
    final entries = _scoringEntries(sets, s1, s2);
    return entries.asMap().entries.map((e) {
      final idx = e.key;
      final row = e.value;
      final isWin = row['label'].toString().contains('勝');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: idx.isEven ? Colors.white : Colors.grey[50],
          border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
          borderRadius: idx == entries.length - 1 ? const BorderRadius.vertical(bottom: Radius.circular(9)) : null,
        ),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isWin ? AppTheme.success : AppTheme.error.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(flex: 3, child: Text(row['label'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: isWin ? FontWeight.w600 : FontWeight.normal))),
          if (s2 != null) ...[
            Expanded(flex: 2, child: Text('${row['pts1']}点', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
            Expanded(flex: 2, child: Text('${row['pts2']}点', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
          ] else
            Expanded(flex: 2, child: Text('${row['pts1']}点', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
        ]),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _scoringEntries(int sets, Map<String, dynamic> s1, Map<String, dynamic>? s2) {
    switch (sets) {
      case 1:
        return [
          {'label': '勝利', 'pts1': s1['win'] ?? 3, 'pts2': s2?['win'] ?? s1['win'] ?? 3},
          {'label': '敗北', 'pts1': s1['lose'] ?? 0, 'pts2': s2?['lose'] ?? s1['lose'] ?? 0},
        ];
      case 3:
        return [
          {'label': '2-0 勝ち', 'pts1': s1['win20'] ?? 10, 'pts2': s2?['win20'] ?? s1['win20'] ?? 10},
          {'label': '2-1 勝ち', 'pts1': s1['win21'] ?? 7, 'pts2': s2?['win21'] ?? s1['win21'] ?? 7},
          {'label': '1-2 負け', 'pts1': s1['lose12'] ?? 2, 'pts2': s2?['lose12'] ?? s1['lose12'] ?? 2},
          {'label': '0-2 負け', 'pts1': s1['lose02'] ?? 0, 'pts2': s2?['lose02'] ?? s1['lose02'] ?? 0},
        ];
      default:
        return [
          {'label': '2-0 勝ち', 'pts1': s1['win20'] ?? 10, 'pts2': s2?['win20'] ?? s1['win20'] ?? 10},
          {'label': '1-1 得失差勝ち', 'pts1': s1['win11'] ?? 7, 'pts2': s2?['win11'] ?? s1['win11'] ?? 7},
          {'label': '1-1 引き分け', 'pts1': s1['draw'] ?? 4, 'pts2': s2?['draw'] ?? s1['draw'] ?? 4},
          {'label': '1-1 得失差負け', 'pts1': s1['lose11'] ?? 2, 'pts2': s2?['lose11'] ?? s1['lose11'] ?? 2},
          {'label': '0-2 負け', 'pts1': s1['lose02'] ?? 0, 'pts2': s2?['lose02'] ?? s1['lose02'] ?? 0},
        ];
    }
  }
}

// ━━━ 全予選合計の順位表ウィジェット ━━━
class _OverallStandingsAggregator extends StatefulWidget {
  final String tournamentId;
  final List<String> roundIds;
  final List<String> myTeamIds;

  const _OverallStandingsAggregator({
    required this.tournamentId,
    required this.roundIds,
    required this.myTeamIds,
  });

  @override
  State<_OverallStandingsAggregator> createState() => _OverallStandingsAggregatorState();
}

class _OverallStandingsAggregatorState extends State<_OverallStandingsAggregator> {
  final _firestore = FirebaseFirestore.instance;
  final List<StreamSubscription<QuerySnapshot>> _subs = [];
  StreamSubscription<DocumentSnapshot>? _rulesSub;
  // key: "roundId/courtId" → team list
  final Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loaded = false;
  // Track standing doc listeners per round
  final List<StreamSubscription<QuerySnapshot>> _standingSubs = [];

  // 決勝ルール情報
  int _tierCount = 3;
  String _finalFormat = '順位別複数';
  bool _finalEnabled = false;

  @override
  void initState() {
    super.initState();
    _subscribeRules();
    _subscribeAll();
  }

  @override
  void didUpdateWidget(covariant _OverallStandingsAggregator old) {
    super.didUpdateWidget(old);
    if (old.roundIds.length != widget.roundIds.length ||
        old.roundIds.join(',') != widget.roundIds.join(',')) {
      _cancelAll();
      _subscribeAll();
    }
  }

  void _subscribeRules() {
    _rulesSub = _firestore.collection('tournaments').doc(widget.tournamentId).snapshots().listen((snap) {
      if (!mounted) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final rules = data['rules'] as Map<String, dynamic>? ?? {};
      final finalRules = rules['final'] as Map<String, dynamic>? ?? {};
      setState(() {
        _tierCount = finalRules['tierCount'] as int? ?? 3;
        _finalFormat = finalRules['format'] as String? ?? '順位別複数';
        _finalEnabled = finalRules['enabled'] as bool? ?? false;
      });
    });
  }

  void _subscribeAll() {
    _data.clear();
    _loaded = false;
    // For each round, listen to standings collection to discover courts
    for (final roundId in widget.roundIds) {
      final sub = _firestore
          .collection('tournaments').doc(widget.tournamentId)
          .collection('rounds').doc(roundId)
          .collection('standings').snapshots()
          .listen((standingsSnap) {
        if (!mounted) return;
        // Remove old team subs for this round
        _removeSubsForRound(roundId);
        // Subscribe to each court's teams
        for (final courtDoc in standingsSnap.docs) {
          _subscribeCourtTeams(roundId, courtDoc.id);
        }
        if (standingsSnap.docs.isEmpty) {
          setState(() => _loaded = true);
        }
      });
      _standingSubs.add(sub);
    }
  }

  void _subscribeCourtTeams(String roundId, String courtId) {
    final key = '$roundId/$courtId';
    final sub = _firestore
        .collection('tournaments').doc(widget.tournamentId)
        .collection('rounds').doc(roundId)
        .collection('standings').doc(courtId)
        .collection('teams').snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _data[key] = snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
        _loaded = true;
      });
    });
    _subs.add(sub);
  }

  void _removeSubsForRound(String roundId) {
    final keysToRemove = _data.keys.where((k) => k.startsWith('$roundId/')).toList();
    for (final key in keysToRemove) {
      _data.remove(key);
    }
  }

  void _cancelAll() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    for (final sub in _standingSubs) {
      sub.cancel();
    }
    _standingSubs.clear();
    _data.clear();
    _loaded = false;
  }

  @override
  void dispose() {
    _rulesSub?.cancel();
    _cancelAll();
    super.dispose();
  }

  /// リーグ名を返す（match_generator.dart と同じロジック）
  List<String> _getLeagueNames(int count) {
    switch (count) {
      case 1: return ['リーグ'];
      case 2: return ['上', '下'];
      case 3: return ['上', '中', '下'];
      case 4: return ['上', '中上', '中下', '下'];
      case 5: return ['上', '中上', '中', '中下', '下'];
      default:
        final names = ['上', '中上', '中', '中下', '下'];
        for (int i = 5; i < count; i++) names.add('第${i + 1}');
        return names;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));

    // Aggregate: sum matchPoints/pointDiff/totalPoints per teamId across all rounds & courts
    final Map<String, Map<String, dynamic>> merged = {};
    for (final teams in _data.values) {
      for (final t in teams) {
        final teamId = t['teamId'] as String? ?? '';
        if (teamId.isEmpty) continue;
        if (merged.containsKey(teamId)) {
          merged[teamId]!['matchPoints'] = (merged[teamId]!['matchPoints'] as num) + ((t['matchPoints'] ?? 0) as num);
          merged[teamId]!['pointDiff'] = (merged[teamId]!['pointDiff'] as num) + ((t['pointDiff'] ?? 0) as num);
          merged[teamId]!['totalPoints'] = (merged[teamId]!['totalPoints'] as num) + ((t['totalPoints'] ?? 0) as num);
        } else {
          merged[teamId] = {
            'teamId': teamId,
            'teamName': t['teamName'] ?? '',
            'matchPoints': (t['matchPoints'] ?? 0) as num,
            'pointDiff': (t['pointDiff'] ?? 0) as num,
            'totalPoints': (t['totalPoints'] ?? 0) as num,
          };
        }
      }
    }

    final allTeams = merged.values.toList();

    if (allTeams.isEmpty) {
      return const Center(child: Text('まだ試合結果がありません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)));
    }

    // Sort: matchPoints desc → pointDiff desc → totalPoints desc
    allTeams.sort((a, b) {
      final mp = (b['matchPoints'] as num).compareTo(a['matchPoints'] as num);
      if (mp != 0) return mp;
      final pd = (b['pointDiff'] as num).compareTo(a['pointDiff'] as num);
      if (pd != 0) return pd;
      return (b['totalPoints'] as num).compareTo(a['totalPoints'] as num);
    });

    // 区分境界を計算（match_generator と同じ ceil ロジック）
    final tierBoundaries = <int, String>{};
    if (_finalEnabled && _finalFormat == '順位別複数' && _tierCount >= 2) {
      final leagueCount = _tierCount.clamp(1, allTeams.length);
      final teamsPerTier = (allTeams.length / leagueCount).ceil();
      final leagueNames = _getLeagueNames(leagueCount);
      for (int t = 1; t < leagueCount; t++) {
        final boundary = t * teamsPerTier;
        if (boundary < allTeams.length) {
          tierBoundaries[boundary] = t < leagueNames.length ? leagueNames[t] : '';
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            const Icon(Icons.leaderboard, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('予選 総合順位', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${allTeams.length}チーム', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        // Column labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: const [
            SizedBox(width: 28, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            Expanded(flex: 3, child: Text('チーム', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary))),
            SizedBox(width: 40, child: Text('勝点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
            SizedBox(width: 40, child: Text('得失', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
            SizedBox(width: 40, child: Text('総得', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
          ]),
        ),
        Divider(height: 1, color: Colors.grey[200]),
        // Team rows
        ...allTeams.asMap().entries.expand((e) {
          final i = e.key;
          final t = e.value;
          final isMyTeam = widget.myTeamIds.contains(t['teamId'] ?? '');
          final isTierBoundary = tierBoundaries.containsKey(i);
          return [
            // 区分境界: 赤い線
            if (isTierBoundary)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                child: Container(height: 2, color: Colors.red),
              )
            else if (i > 0)
              Divider(height: 1, color: Colors.grey[200]),
            Container(
              color: isMyTeam ? Colors.red.withValues(alpha: 0.08) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: i == 0 ? Colors.amber[700] : (i < 3 ? AppTheme.primaryColor : AppTheme.textPrimary)))),
                  Expanded(flex: 3, child: Text(t['teamName'] ?? '', style: TextStyle(fontSize: 14,
                      color: isMyTeam ? Colors.red : null,
                      fontWeight: isMyTeam ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 40, child: Text('${t['matchPoints']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('${t['pointDiff']}', style: TextStyle(fontSize: 13,
                      color: (t['pointDiff'] as num) >= 0 ? AppTheme.success : AppTheme.error), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('${t['totalPoints']}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                ]),
              ),
            ),
          ];
        }),
      ]),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ━━━ 主催者メニュー全画面 ━━━
class _OrganizerMenuScreen extends StatelessWidget {
  final Map<String, dynamic> tournData;
  final String tournamentId;
  final VoidCallback onEditTournament;
  final VoidCallback onStatusChange;
  final VoidCallback onSelfEntry;
  final VoidCallback onCheckIn;
  final VoidCallback onCsvMenu;
  final VoidCallback onDeleteTeams;
  final VoidCallback onFinance;
  final VoidCallback onEditors;
  final VoidCallback onAnnouncement;
  final VoidCallback onGenerateRound2;
  final VoidCallback onGenerateFinals;
  final VoidCallback onReset;
  final VoidCallback onEndTournament;
  final VoidCallback onSaveTemplate;
  final VoidCallback onDelete;

  const _OrganizerMenuScreen({
    required this.tournData,
    required this.tournamentId,
    required this.onEditTournament,
    required this.onStatusChange,
    required this.onSelfEntry,
    required this.onCheckIn,
    required this.onCsvMenu,
    required this.onDeleteTeams,
    required this.onFinance,
    required this.onEditors,
    required this.onAnnouncement,
    required this.onGenerateRound2,
    required this.onGenerateFinals,
    required this.onReset,
    required this.onEndTournament,
    required this.onSaveTemplate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final rules = tournData['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};
    final prelimRounds = preliminary['rounds'] ?? 1;
    final finalEnabled = (rules['final'] as Map<String, dynamic>?)?['enabled'] ?? true;
    final status = tournData['status'] ?? '準備中';
    final isRunning = status == '開催中' || status == '決勝中' || status == '順位決定中';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('大会主催者メニュー', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
        children: [
          // ━━━ 大会情報 ━━━
          _sectionLabel('大会情報'),
          _menuTile(context, Icons.edit_outlined, '大会を編集', '名前・日程・会場・ルールなど', onEditTournament, color: AppTheme.primaryColor),
          _menuTile(context, Icons.sync_outlined, 'ステータス変更', '準備中 → 募集中 → 締切 → 開催中 → 終了', onStatusChange, color: AppTheme.primaryColor),

          // ━━━ 参加者管理 ━━━
          _sectionLabel('参加者管理'),
          _menuTile(context, Icons.how_to_reg, '自分もエントリー', 'チームを作成してエントリー', onSelfEntry, color: AppTheme.success),
          _menuTile(context, Icons.qr_code_scanner, '受付管理（QR）', 'QRコードでチェックイン管理', onCheckIn, color: AppTheme.success),
          _menuTile(context, Icons.upload_file, 'CSVインポート', 'エントリー・対戦表・決勝のCSV管理', onCsvMenu, color: AppTheme.success),
          _menuTile(context, Icons.delete_sweep, 'エントリーチーム削除', '選択したチームをエントリーから削除', onDeleteTeams, isDestructive: true),

          // ━━━ 運営 ━━━
          _sectionLabel('運営'),
          _menuTile(context, Icons.account_balance_wallet_outlined, '収支管理', '参加費の入金状況・経費を管理', onFinance, color: AppTheme.accentColor),
          _menuTile(context, Icons.people_outline, '権限管理', '他のユーザーに編集権限を付与', onEditors, color: AppTheme.accentColor),
          _menuTile(context, Icons.campaign_outlined, 'お知らせ送信', '全参加者に通知を送信', onAnnouncement, color: AppTheme.accentColor),

          // ━━━ 試合進行 ━━━
          _sectionLabel('試合進行'),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tournaments').doc(tournamentId)
                .collection('rounds').snapshots(),
            builder: (context, roundsSnap) {
              final roundDocs = roundsSnap.data?.docs ?? [];
              final existingRoundNumbers = roundDocs.map((d) => (d.data() as Map<String, dynamic>)['roundNumber'] ?? 1).toSet();
              final hasRound1 = existingRoundNumbers.contains(1);
              final hasRound2 = existingRoundNumbers.contains(2);
              final hasAnyRound = roundDocs.isNotEmpty;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('tournaments').doc(tournamentId)
                    .collection('brackets').snapshots(),
                builder: (context, bracketsSnap) {
                  final hasBrackets = bracketsSnap.hasData && bracketsSnap.data!.docs.isNotEmpty;

                  return Column(children: [
                    if (prelimRounds >= 2 && hasRound1 && !hasRound2)
                      _menuTile(context, Icons.replay, '予選2 生成', '予選1完了後に予選2の対戦表を生成', onGenerateRound2, color: AppTheme.info),
                    if (finalEnabled && hasRound1 && !hasBrackets)
                      _menuTile(context, Icons.emoji_events, '順位決定戦生成', '予選完了後に決勝トーナメントを生成', onGenerateFinals, color: AppTheme.info),
                    if (hasAnyRound || hasBrackets)
                      _menuTile(context, Icons.refresh, 'リセット', '対戦表・スコアをリセット', onReset, color: AppTheme.info),
                  ]);
                },
              );
            },
          ),

          // ━━━ 大会を終了する ━━━
          if (isRunning) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); onEndTournament(); },
                  icon: const Icon(Icons.flag, size: 18),
                  label: const Text('大会を終了する', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],

          // ━━━ その他 ━━━
          _sectionLabel('その他'),
          _menuTile(context, Icons.bookmark_add_outlined, 'テンプレートに保存', '大会設定をテンプレートとして保存', onSaveTemplate, color: AppTheme.textSecondary),
          _menuTile(context, Icons.delete_outline, '大会を削除', 'この大会を完全に削除', onDelete, isDestructive: true),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = AppTheme.primaryColor, bool isDestructive = false}) {
    final c = isDestructive ? AppTheme.error : color;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: c),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDestructive ? AppTheme.error : AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }
}

// ━━━ CSVインポートメニュー画面 ━━━
class _CsvImportMenuScreen extends StatelessWidget {
  final int prelimRounds;
  final bool finalEnabled;
  final VoidCallback onEntryUpload;
  final VoidCallback onEntryTemplate;
  final VoidCallback onMatchTableUpload1;
  final VoidCallback onMatchTableUpload2;
  final VoidCallback onMatchTableTemplate;
  final VoidCallback onFinalsUpload;
  final VoidCallback onFinalsTemplate;

  const _CsvImportMenuScreen({
    required this.prelimRounds,
    required this.finalEnabled,
    required this.onEntryUpload,
    required this.onEntryTemplate,
    required this.onMatchTableUpload1,
    required this.onMatchTableUpload2,
    required this.onMatchTableTemplate,
    required this.onFinalsUpload,
    required this.onFinalsTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('CSVインポート', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
        children: [
          // ━━━ エントリー用 ━━━
          _sectionLabel('エントリー用'),
          _csvTile(context, Icons.upload_file, 'チーム一括登録', 'CSVファイルからチームをまとめて登録', onEntryUpload, color: AppTheme.success),
          _csvTile(context, Icons.download, 'テンプレートDL', 'エントリー用のCSVテンプレート', onEntryTemplate, color: AppTheme.success),

          // ━━━ 予選対戦表 ━━━
          _sectionLabel('予選対戦表'),
          _csvTile(context, Icons.upload_file, '予選1 アップロード', 'CSVファイルから予選1の対戦表をインポート', onMatchTableUpload1, color: AppTheme.info),
          if (prelimRounds >= 2)
            _csvTile(context, Icons.upload_file, '予選2 アップロード', 'CSVファイルから予選2の対戦表をインポート', onMatchTableUpload2, color: AppTheme.info),
          _csvTile(context, Icons.download, 'テンプレートDL', '予選対戦表用のCSVテンプレート', onMatchTableTemplate, color: AppTheme.info),

          // ━━━ 決勝対戦表 ━━━
          if (finalEnabled) ...[
            _sectionLabel('決勝対戦表'),
            _csvTile(context, Icons.upload_file, '決勝 アップロード', 'CSVファイルから決勝トーナメントをインポート', onFinalsUpload, color: AppTheme.accentColor),
            _csvTile(context, Icons.download, 'テンプレートDL', '決勝対戦表用のCSVテンプレート', onFinalsTemplate, color: AppTheme.accentColor),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
    );
  }

  Widget _csvTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = AppTheme.primaryColor}) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }
}
