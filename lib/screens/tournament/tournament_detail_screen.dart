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
  const TournamentDetailScreen({super.key, required this.tournament, this.autoCheckIn = false});
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

  String get _tournamentId => widget.tournament['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    final status = widget.tournament['status'] as String;
    _isEntryDeadlinePassed = status == '満員' || status == '開催済み' || status == '開催中' || status == '決勝中' || status == '順位決定中' || status == '終了' || status.contains('完了') || widget.tournament['organizerId'] == FirebaseAuth.instance.currentUser?.uid;
    _isFollowing = widget.tournament['isFollowing'] as bool? ?? true;
    _tabController = TabController(
      length: _isEntryDeadlinePassed ? 5 : 4,
      vsync: this,
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
    final entries = await _firestore.collection('tournaments').doc(_tournamentId)
        .collection('entries').where('enteredBy', isEqualTo: uid).get();
    final teamIds = entries.docs.map((d) => d['teamId'] as String? ?? '').where((id) => id.isNotEmpty).toList();
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
                child: Text(t['name'] as String,
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
                child: Text(t['type'] as String, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 日付・チーム数・場所を1行に
          Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(t['date'] as String, style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                _buildTimelineRow(live['captainMeetingTime'] as String? ?? t['captainMeetingTime'] as String? ?? '8:45', '代表者会議', Icons.groups),
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
                        Text('主催者', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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

            // ━━━ 大会の流れ ━━━
            _buildCard(
              title: '大会の流れ',
              titleIcon: Icons.timeline,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildFlowStep(1, 'エントリー受付', liveStatus == '募集中', liveCurrentTeams > 0),
                _buildFlowStep(2, '予選リーグ（ラウンドロビン）', liveStatus == '開催中', false),
                if ((livePrelim['rounds'] ?? 1) > 1)
                  _buildFlowStep(3, '予選2（ランク別再編成）', false, false),
                _buildFlowStep((livePrelim['rounds'] ?? 1) > 1 ? 4 : 3, '順位決定戦', liveStatus == '順位決定中', false),
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



  // ━━━ ステータス変更 ━━━
  void _showStatusDialog(String currentStatus) {
    final statuses = ['準備中', '募集中', '開催中', '終了'];
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
      final members = <String, String>{};
      for (int i = 1; i < row.length; i++) {
        final name = row[i].toString().trim();
        if (name.isNotEmpty) {
          members['p${i}'] = name;
        }
      }
      teams.add({
        'teamName': teamName,
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

    // プレビューダイアログ
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.upload_file, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text('${teams.length}チームを登録', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: teams.length,
            itemBuilder: (ctx, i) {
              final t = teams[i];
              final members = t['members'] as Map<String, String>;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
                title: Text(t['teamName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(members.values.join(', '), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              );
            },
          ),
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
    );

    if (confirmed != true) return;

    // Firestoreに一括登録
    int count = 0;
    final batch = _firestore.batch();
    for (final t in teams) {
      final entryRef = _firestore.collection('tournaments').doc(_tournamentId).collection('entries').doc();
      batch.set(entryRef, {
        'teamId': entryRef.id,
        'teamName': t['teamName'],
        'leaderName': (t['members'] as Map<String, String>).values.firstOrNull ?? '',
        'memberCount': t['memberCount'],
        'memberNames': t['members'],
        'enteredBy': uid,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
          const SizedBox(width: 8),
          Text('${bData['bracketName'] ?? '順位決定'}トーナメント',
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
            final roundLabel = m['round'] == 'semi' ? '準決勝' : (m['round'] == 'final' ? '決勝' : '');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha:0.3))),
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
                          color: status == 'completed' ? Colors.amber.withValues(alpha:0.1) : Colors.grey[100],
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
  void _showMemberList(String teamName, Map<String, dynamic> memberNames) {
    final members = memberNames.entries.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: isFirst ? Text('キャプテン', style: TextStyle(fontSize: 12, color: AppTheme.accentColor)) : null,
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
                ...entries.map((doc) {
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
                      onTap: isMyTeam ? () => _showMemberList(teamName.toString(), memberNames) : null,
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
                              Text('キャプテン: $leader / ${memberUids.length}人', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                              child: Text('主催者', style: TextStyle(fontSize: 10, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
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
                          ? '自分＋メンバー2人以上を選択してください'
                          : '${selectedMembers.length + 1}人（自分＋${selectedMembers.length}人選択中）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedMembers.length < 2 ? AppTheme.textHint : AppTheme.primaryColor,
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
                          // 自分 + 選択メンバーで3人以上必要
                          if (selectedMembers.length < 2) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('メンバーは自分を含めて3人以上必要です'), backgroundColor: AppTheme.warning));
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
                    label: const Text('主催者メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                label: const Text('主催者メニュー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          _menuTile(ctx, Icons.qr_code_scanner, 'QRスキャンで受付', '主催者がカメラでチームのQRを読み取る', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')));
          }, color: AppTheme.success),
          _menuTile(ctx, Icons.checklist, '手動チェックイン', 'リストから手動でチェックイン', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')));
          }, color: AppTheme.success),
          _menuTile(ctx, Icons.qr_code, '大会QRコードを表示', '参加者がスキャンして自動チェックイン', () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CheckInScreen(tournamentId: _tournamentId, tournamentName: tournData['title'] ?? '')));
          }, color: AppTheme.primaryColor),
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
        onCsvImport: _importTeamsFromCsv,
        onTestTeams: _addTestTeams,
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
                            label: const Text('主催者メニュー', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

        // 大会当日 & エントリー済み → チェックインボタン
        if (_isTournamentToday() && _myEntryTeamId.isNotEmpty) {
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
                Text(widget.tournament['name'] as String,
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
  final VoidCallback onCsvImport;
  final VoidCallback onTestTeams;
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
    required this.onCsvImport,
    required this.onTestTeams,
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
        title: const Text('主催者メニュー', style: TextStyle(fontWeight: FontWeight.bold)),
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
          _menuTile(context, Icons.sync_outlined, 'ステータス変更', '準備中 → 募集中 → 開催中 → 終了', onStatusChange, color: AppTheme.primaryColor),

          // ━━━ 参加者管理 ━━━
          _sectionLabel('参加者管理'),
          _menuTile(context, Icons.how_to_reg, '自分もエントリー', 'チームを作成してエントリー', onSelfEntry, color: AppTheme.success),
          _menuTile(context, Icons.qr_code_scanner, '受付管理（QR）', 'QRコードでチェックイン管理', onCheckIn, color: AppTheme.success),
          _menuTile(context, Icons.upload_file, 'CSV一括登録', 'CSVファイルからチームをまとめて登録', onCsvImport, color: AppTheme.success),
          _menuTile(context, Icons.group_add, 'テストチーム追加', 'テスト用のダミーチームを追加', onTestTeams, color: AppTheme.success),

          // ━━━ 運営 ━━━
          _sectionLabel('運営'),
          _menuTile(context, Icons.account_balance_wallet_outlined, '収支管理', '参加費の入金状況・経費を管理', onFinance, color: AppTheme.accentColor),
          _menuTile(context, Icons.people_outline, '権限管理', '他のユーザーに編集権限を付与', onEditors, color: AppTheme.accentColor),
          _menuTile(context, Icons.campaign_outlined, 'お知らせ送信', '全参加者に通知を送信', onAnnouncement, color: AppTheme.accentColor),

          // ━━━ 試合進行 ━━━
          _sectionLabel('試合進行'),
          if (prelimRounds >= 2)
            _menuTile(context, Icons.replay, '予選2 生成', '予選2ラウンドの対戦表を生成', onGenerateRound2, color: AppTheme.info),
          if (finalEnabled)
            _menuTile(context, Icons.emoji_events, '順位決定戦生成', '決勝トーナメントを生成', onGenerateFinals, color: AppTheme.info),
          _menuTile(context, Icons.refresh, 'リセット', '対戦表・スコアをリセット', onReset, color: AppTheme.info),

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
