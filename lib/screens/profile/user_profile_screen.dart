import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../chat/chat_screen.dart';
import '../tournament/tournament_detail_screen.dart';
import 'follow_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isFollowing = false;
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  int _followingCount = 0;
  int _followersCount = 0;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isMyProfile => widget.userId == _currentUid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc = await _firestore.collection('users').doc(widget.userId).get();
    final userData = userDoc.data() ?? {};

    final followingSnap = await _firestore
        .collection('users').doc(widget.userId).collection('following').get();
    final followersSnap = await _firestore
        .collection('users').doc(widget.userId).collection('followers').get();

    bool isFollowing = false;
    if (!_isMyProfile) {
      final followDoc = await _firestore
          .collection('users').doc(_currentUid).collection('following').doc(widget.userId).get();
      isFollowing = followDoc.exists;
    }

    if (mounted) {
      setState(() {
        _userData = userData;
        _followingCount = followingSnap.docs.length;
        _followersCount = followersSnap.docs.length;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  String _safeString(dynamic value) {
    if (value is String) return value;
    if (value is Map) return value.values.join(' ');
    return value?.toString() ?? '';
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  Future<void> _startDmWith(String otherUid, String otherName) async {
    final myUid = _currentUid;
    if (myUid.isEmpty) return;

    final existing = await _firestore
        .collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('members', arrayContains: myUid)
        .get();

    String? chatId;
    for (final doc in existing.docs) {
      final members = List<String>.from(doc['members'] ?? []);
      if (members.contains(otherUid)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myName = (myDoc.data()?['nickname'] as String?) ?? '自分';

      final ref = await _firestore.collection('chats').add({
        'type': 'dm',
        'members': [myUid, otherUid],
        'memberNames': {myUid: myName, otherUid: otherName},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastRead': {myUid: FieldValue.serverTimestamp()},
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = ref.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId!,
            chatTitle: otherName,
            chatType: 'dm',
            otherUserId: otherUid,
          ),
        ),
      );
    }
  }

  void _showBlockReportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.error),
              title: const Text('このユーザーをブロック'),
              subtitle: const Text('相手の投稿やメッセージが非表示になります', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmBlock();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.warning),
              title: const Text('通報する'),
              subtitle: const Text('不適切なコンテンツや行為を報告します', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ブロックしますか？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('ブロックすると相手の投稿やメッセージが表示されなくなります。設定からいつでも解除できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('users').doc(_currentUid).collection('blockedUsers').doc(widget.userId).set({
                'blockedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ユーザーをブロックしました'), backgroundColor: AppTheme.success),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, minimumSize: const Size(100, 40)),
            child: const Text('ブロック'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    String selectedReason = '';
    final reasons = ['スパム・迷惑行為', '不適切なコンテンツ', 'なりすまし', 'ハラスメント', 'その他'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('通報理由を選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(fontSize: 14)),
              value: reason,
              groupValue: selectedReason,
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setDialogState(() => selectedReason = v ?? ''),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: selectedReason.isEmpty ? null : () async {
                await _firestore.collection('reports').add({
                  'reporterId': _currentUid,
                  'targetUserId': widget.userId,
                  'reason': selectedReason,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('通報を送信しました。ご協力ありがとうございます。'), backgroundColor: AppTheme.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              child: const Text('送信'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isMyProfile) return;

    final myRef = _firestore.collection('users').doc(_currentUid);
    final targetRef = _firestore.collection('users').doc(widget.userId);

    if (_isFollowing) {
      await myRef.collection('following').doc(widget.userId).delete();
      await targetRef.collection('followers').doc(_currentUid).delete();
      await myRef.update({'followingCount': FieldValue.increment(-1)});
      await targetRef.update({'followersCount': FieldValue.increment(-1)});
      setState(() {
        _isFollowing = false;
        _followersCount--;
      });
    } else {
      final targetNickname = (_userData['nickname'] as String?) ?? 'ユーザー';
      final myDoc = await myRef.get();
      final myNickname = (myDoc.data()?['nickname'] as String?) ?? 'ユーザー';

      await myRef.collection('following').doc(widget.userId).set({
        'nickname': targetNickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await targetRef.collection('followers').doc(_currentUid).set({
        'nickname': myNickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await myRef.update({'followingCount': FieldValue.increment(1)});
      await targetRef.update({'followersCount': FieldValue.increment(1)});
      setState(() {
        _isFollowing = true;
        _followersCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('プロフィール')),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final nickname = _safeString(_userData['nickname']).isEmpty
        ? '名前なし' : _safeString(_userData['nickname']);
    final bio = _safeString(_userData['bio']);
    final avatarUrl = _safeString(_userData['avatarUrl']);
    final rawArea = _userData['area'];
    final area = rawArea is String
        ? rawArea
        : rawArea is Map
            ? '${rawArea['prefecture'] ?? ''}${rawArea['city'] ?? ''}'
            : '';
    final experience = _safeString(_userData['experience']);
    final seasonPoints = _safeInt(_userData['seasonPoints']);
    final totalPoints = _safeInt(_userData['totalPoints']);
    final stats = _userData['stats'] is Map<String, dynamic>
        ? _userData['stats'] as Map<String, dynamic>
        : <String, dynamic>{};
    final tournamentsPlayed = _safeInt(stats['tournamentsPlayed']);
    final championships = _safeInt(stats['championships']);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ━━━ グラデーションヘッダー ━━━
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor, AppTheme.primaryLight],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 14),
                  child: Column(
                    children: [
                      // ── トップバー ──
                      Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(nickname,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!_isMyProfile)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                              onPressed: _showBlockReportSheet,
                              icon: const Icon(Icons.more_horiz, size: 22, color: Colors.white),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ── プロフィール行 ──
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                            ),
                            child: avatarUrl.isNotEmpty
                                ? CircleAvatar(
                                    radius: 30,
                                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  )
                                : CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                                    child: Text(
                                      nickname.isNotEmpty ? nickname[0] : '?',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nickname,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (experience.isNotEmpty) _buildHeaderTag('競技歴 $experience'),
                                    if (area.isNotEmpty) _buildHeaderTag(area),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(bio,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), height: 1.3),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // ── フォロー / フォロワー ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFollowCount('$_followingCount', 'フォロー', () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(
                                  userId: widget.userId, title: 'フォロー中', isFollowers: false)));
                          }),
                          Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 24),
                              color: Colors.white.withValues(alpha: 0.25)),
                          _buildFollowCount('$_followersCount', 'フォロワー', () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(
                                  userId: widget.userId, title: 'フォロワー', isFollowers: true)));
                          }),
                        ],
                      ),
                      // ── フォロー / メッセージ ボタン ──
                      if (!_isMyProfile) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleFollow,
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _isFollowing
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: _isFollowing ? 1.5 : 0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isFollowing)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.check, size: 16, color: Colors.white),
                                        ),
                                      Text(
                                        _isFollowing ? 'フォロー中' : 'フォローする',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _isFollowing ? Colors.white : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _startDmWith(widget.userId, nickname),
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                ),
                                child: const Center(
                                  child: Text('メッセージ',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ━━━ ダッシュボード（スタッツ） ━━━
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildDashboardStat(Icons.calendar_today_rounded, '$seasonPoints', 'シーズンPt', AppTheme.accentColor)),
                    Container(width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(child: _buildDashboardStat(Icons.star_rounded, '$totalPoints', '通算Pt', AppTheme.textSecondary)),
                    Container(width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(child: _buildDashboardStat(Icons.emoji_events_rounded, '$tournamentsPlayed', '大会参加', AppTheme.primaryColor)),
                    Container(width: 1, height: 36, color: Colors.grey[200]),
                    Expanded(child: _buildDashboardStat(Icons.military_tech_rounded, '$championships', '優勝', AppTheme.warning)),
                  ],
                ),
              ),
            ),
          ),

          // ━━━ コンテンツ ━━━
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ━━━ 大会結果カードセクション ━━━
                _buildCardSection(
                  title: '大会結果',
                  icon: Icons.emoji_events_rounded,
                  child: _TournamentCardsRow(userId: widget.userId),
                ),
                const SizedBox(height: 16),

                // ━━━ ガジェットカードセクション ━━━
                _buildCardSection(
                  title: 'ガジェット',
                  icon: Icons.devices_other_rounded,
                  child: _GadgetCardsRow(userId: widget.userId),
                ),
                const SizedBox(height: 16),

                // ━━━ バッジコレクション ━━━
                _buildCardSection(
                  title: 'バッジコレクション',
                  icon: Icons.workspace_premium_rounded,
                  child: _BadgeCollectionRow(userId: widget.userId),
                ),
                const SizedBox(height: 16),

                // ━━━ 投稿 ━━━
                _buildCardSection(
                  title: '投稿',
                  icon: Icons.article_rounded,
                  child: _RecentPostsSection(userId: widget.userId),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── ヘッダー上のタグ ──
  Widget _buildHeaderTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }

  // ── フォロー数 ──
  Widget _buildFollowCount(String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ── ダッシュボードスタッツ ──
  Widget _buildDashboardStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.1)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── カードセクション ──
  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 大会結果カード（横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TournamentCardsRow extends StatefulWidget {
  final String userId;
  const _TournamentCardsRow({required this.userId});

  @override
  State<_TournamentCardsRow> createState() => _TournamentCardsRowState();
}

class _TournamentCardsRowState extends State<_TournamentCardsRow> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadTournaments();
  }

  Future<List<Map<String, dynamic>>> _loadTournaments() async {
    final firestore = FirebaseFirestore.instance;
    final uid = widget.userId;
    final resultMap = <String, Map<String, dynamic>>{};

    // 主催した大会
    final organized = await firestore
        .collection('tournaments')
        .where('organizerId', isEqualTo: uid)
        .get();
    for (final doc in organized.docs) {
      final data = doc.data();
      if (data['status'] != '終了') continue;
      data['id'] = doc.id;
      resultMap[doc.id] = data;
    }

    // エントリーした大会を検索
    final allTournaments = await firestore
        .collection('tournaments')
        .orderBy('date', descending: true)
        .limit(100)
        .get();

    for (final doc in allTournaments.docs) {
      if (resultMap.containsKey(doc.id)) continue;
      final data = doc.data();
      if (data['status'] != '終了') continue;
      final entries = await firestore
          .collection('tournaments')
          .doc(doc.id)
          .collection('entries')
          .where('enteredBy', isEqualTo: uid)
          .limit(1)
          .get();
      if (entries.docs.isNotEmpty) {
        data['id'] = doc.id;
        resultMap[doc.id] = data;
      }
    }

    final result = resultMap.values.toList()
      ..sort((a, b) => ((b['date'] ?? '') as String).compareTo((a['date'] ?? '') as String));
    if (result.length > 10) result.removeRange(10, result.length);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyCard('データの取得に失敗しました', Icons.error_outline);
        }
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final tournaments = snapshot.data!;
        if (tournaments.isEmpty) {
          return _buildEmptyCard('まだ大会結果がありません', Icons.emoji_events_outlined);
        }

        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final d = tournaments[index];
              final title = (d['title'] ?? d['name'] ?? '大会') as String;
              final date = (d['date'] ?? '') as String;
              final location = (d['location'] ?? d['venue'] ?? '') as String;
              final status = (d['status'] ?? '') as String;
              final type = (d['type'] ?? '') as String;
              final docId = d['id'] as String;

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {...d, 'id': docId, 'name': d['title'] ?? d['name'] ?? ''}))),
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status.isEmpty ? '終了' : status,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          ),
                          if (type.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentColor)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.place, size: 11, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(location, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ガジェットカード（横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _GadgetCardsRow extends StatelessWidget {
  final String userId;
  const _GadgetCardsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(userId).collection('gadgets')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final gadgets = (snapshot.data?.docs ?? []).toList()
          ..sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final orderA = (dataA['sortOrder'] as num?) ?? 999999;
            final orderB = (dataB['sortOrder'] as num?) ?? 999999;
            return orderA.compareTo(orderB);
          });

        if (gadgets.isEmpty) {
          return _buildEmptyCard('ガジェットがまだありません', Icons.devices_other_outlined);
        }

        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gadgets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final d = gadgets[index].data() as Map<String, dynamic>;
              final name = (d['name'] ?? '') as String;
              final category = (d['category'] ?? '') as String;
              final imageUrl = (d['imageUrl'] ?? '') as String;
              final memo = (d['memo'] ?? '') as String;
              final amazonAffiliateUrl = (d['amazonAffiliateUrl'] ?? '') as String;
              final rakutenAffiliateUrl = (d['rakutenAffiliateUrl'] ?? '') as String;

              return GestureDetector(
                onTap: () {
                  // アフィリエイトリンクがあれば開く
                  final url = amazonAffiliateUrl.isNotEmpty
                      ? amazonAffiliateUrl
                      : rakutenAffiliateUrl.isNotEmpty
                          ? rakutenAffiliateUrl
                          : '';
                  if (url.isNotEmpty) {
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 正方形画像エリア ──
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 24)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: Icon(Icons.devices_other, color: Colors.grey, size: 24)),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                                  child: const Center(child: Icon(Icons.devices_other, color: AppTheme.primaryColor, size: 28)),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (category.isNotEmpty && category != 'カテゴリなし') ...[
                              const SizedBox(height: 2),
                              Text(category, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                            if (memo.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(memo, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// バッジコレクション（横スクロール）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BadgeCollectionRow extends StatelessWidget {
  final String userId;
  const _BadgeCollectionRow({required this.userId});

  static const _badgeDefinitions = [
    _BadgeDef('初参加', Icons.flag_rounded, Color(0xFF4CAF50), 'tournamentsPlayed', 1),
    _BadgeDef('5大会参加', Icons.emoji_events_rounded, Color(0xFF2196F3), 'tournamentsPlayed', 5),
    _BadgeDef('10大会参加', Icons.emoji_events_rounded, Color(0xFF9C27B0), 'tournamentsPlayed', 10),
    _BadgeDef('初優勝', Icons.military_tech_rounded, Color(0xFFFF9800), 'championships', 1),
    _BadgeDef('3回優勝', Icons.military_tech_rounded, Color(0xFFF44336), 'championships', 3),
    _BadgeDef('100Pt達成', Icons.star_rounded, Color(0xFFFFC107), 'totalPoints', 100),
    _BadgeDef('500Pt達成', Icons.star_rounded, Color(0xFFFF5722), 'totalPoints', 500),
    _BadgeDef('1000Pt達成', Icons.diamond_rounded, Color(0xFFE91E63), 'totalPoints', 1000),
    _BadgeDef('ガジェット5個', Icons.devices_other_rounded, Color(0xFF00BCD4), 'gadgetCount', 5),
    _BadgeDef('フォロワー10', Icons.people_rounded, Color(0xFF795548), 'followersCount', 10),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final stats = data['stats'] is Map<String, dynamic>
            ? data['stats'] as Map<String, dynamic>
            : <String, dynamic>{};

        final values = {
          'tournamentsPlayed': _intVal(stats['tournamentsPlayed']),
          'championships': _intVal(stats['championships']),
          'totalPoints': _intVal(data['totalPoints']),
          'gadgetCount': _intVal(data['gadgetCount']),
          'followersCount': _intVal(data['followersCount']),
        };

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _badgeDefinitions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = _badgeDefinitions[index];
              final currentValue = values[badge.statKey] ?? 0;
              final earned = currentValue >= badge.threshold;

              return Container(
                width: 90,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: earned ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: earned ? badge.color.withValues(alpha: 0.4) : Colors.grey[200]!,
                    width: earned ? 1.5 : 1,
                  ),
                  boxShadow: earned
                      ? [BoxShadow(color: badge.color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned
                            ? badge.color.withValues(alpha: 0.12)
                            : Colors.grey[200],
                        border: earned
                            ? Border.all(color: badge.color.withValues(alpha: 0.3), width: 2)
                            : null,
                      ),
                      child: Icon(
                        badge.icon,
                        color: earned ? badge.color : Colors.grey[400],
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: earned ? FontWeight.bold : FontWeight.normal,
                        color: earned ? AppTheme.textPrimary : AppTheme.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (!earned)
                      Text(
                        '$currentValue/${badge.threshold}',
                        style: TextStyle(fontSize: 9, color: AppTheme.textHint),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  int _intVal(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }
}

class _BadgeDef {
  final String name;
  final IconData icon;
  final Color color;
  final String statKey;
  final int threshold;
  const _BadgeDef(this.name, this.icon, this.color, this.statKey, this.threshold);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 投稿セクション（いいね・コメント・画像拡大対応）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RecentPostsSection extends StatefulWidget {
  final String userId;
  const _RecentPostsSection({required this.userId});

  @override
  State<_RecentPostsSection> createState() => _RecentPostsSectionState();
}

class _RecentPostsSectionState extends State<_RecentPostsSection> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(uid);
    final postRef = _firestore.collection('posts').doc(postId);
    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
      await postRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  void _showCommentSheet(String postId) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                const Text('コメント', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('posts').doc(postId).collection('comments')
                        .orderBy('createdAt', descending: false).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                      }
                      final comments = snapshot.data?.docs ?? [];
                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('まだコメントはありません', style: TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final data = comments[index].data() as Map<String, dynamic>;
                          final cId = comments[index].id;
                          final nick = (data['userNickname'] as String?) ?? '名無し';
                          final text = (data['text'] as String?) ?? '';
                          final ts = data['createdAt'] as Timestamp?;
                          final t = _formatTimeAgo(ts);
                          final isMine = data['userId'] == FirebaseAuth.instance.currentUser?.uid;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  child: Text(nick.isNotEmpty ? nick[0] : '?',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(nick, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        const SizedBox(width: 6),
                                        Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                                        const Spacer(),
                                        if (isMine) GestureDetector(
                                          onTap: () async {
                                            await _firestore.collection('posts').doc(postId).collection('comments').doc(cId).delete();
                                            await _firestore.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(-1)});
                                          },
                                          child: Icon(Icons.close, size: 16, color: AppTheme.textHint),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // 入力欄
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(24)),
                            child: TextField(
                              controller: commentController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'コメントを入力...',
                                hintStyle: TextStyle(color: AppTheme.textHint),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final txt = commentController.text.trim();
                            if (txt.isEmpty) return;
                            commentController.clear();
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            try {
                              final uDoc = await _firestore.collection('users').doc(uid).get();
                              final uName = (uDoc.data()?['nickname'] as String?) ?? '名無し';
                              await _firestore.collection('posts').doc(postId).collection('comments').add({
                                'userId': uid,
                                'userNickname': uName,
                                'text': txt,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              await _firestore.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});
                            } catch (_) {}
                          },
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(18)),
                            child: const Icon(Icons.send, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => commentController.dispose());
  }

  void _showImageViewer(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ImageViewerScreen(images: images, initialIndex: initialIndex),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('posts')
                .where('userId', isEqualTo: widget.userId)
                .limit(5)
                .get(),
            builder: (context, futureSnap) {
              if (!futureSnap.hasData) {
                return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final posts = futureSnap.data?.docs ?? [];
              if (posts.isEmpty) return _buildEmptyCard('まだ投稿がありません', Icons.article_outlined);
              return _buildPostCards(posts);
            },
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) return _buildEmptyCard('まだ投稿がありません', Icons.article_outlined);
        return _buildPostCards(posts);
      },
    );
  }

  Widget _buildPostCards(List<QueryDocumentSnapshot> posts) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: posts.map((doc) {
          final postId = doc.id;
          final data = doc.data() as Map<String, dynamic>;
          final text = (data['text'] ?? '') as String;
          final images = data['images'] is List ? List<String>.from(data['images']) : <String>[];
          final nickname = (data['userNickname'] ?? '') as String;
          final avatarUrl = (data['userAvatarUrl'] ?? '') as String;
          final createdAt = data['createdAt'] as Timestamp?;
          final timeAgo = _formatTimeAgo(createdAt);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ユーザー情報ヘッダー ──
                Row(
                  children: [
                    avatarUrl.isNotEmpty
                        ? CircleAvatar(radius: 16, backgroundImage: CachedNetworkImageProvider(avatarUrl),
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1))
                        : CircleAvatar(radius: 16, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nickname.isNotEmpty ? nickname : '名無し',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    Text(timeAgo, style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
                      maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
                // ── 画像 ──
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildImageGrid(images),
                ],
                // ── いいね・コメントボタン ──
                const SizedBox(height: 10),
                Row(
                  children: [
                    // いいねボタン（リアルタイム）
                    if (uid != null)
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('posts').doc(postId).collection('likes').doc(uid).snapshots(),
                        builder: (context, likeSnap) {
                          final isLiked = likeSnap.data?.exists ?? false;
                          return GestureDetector(
                            onTap: () => _toggleLike(postId),
                            child: Row(
                              children: [
                                Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 20, color: isLiked ? Colors.red : AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: _firestore.collection('posts').doc(postId).snapshots(),
                                  builder: (context, postSnap) {
                                    final count = (postSnap.data?.data() as Map<String, dynamic>?)?['likesCount'] ?? 0;
                                    return Text('$count', style: TextStyle(fontSize: 13,
                                        color: isLiked ? Colors.red : AppTheme.textSecondary));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (uid == null) ...[
                      Icon(Icons.favorite_border, size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text('${data['likesCount'] ?? 0}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(width: 20),
                    // コメントボタン
                    GestureDetector(
                      onTap: () => _showCommentSheet(postId),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          StreamBuilder<DocumentSnapshot>(
                            stream: _firestore.collection('posts').doc(postId).snapshots(),
                            builder: (context, postSnap) {
                              final count = (postSnap.data?.data() as Map<String, dynamic>?)?['commentsCount'] ?? 0;
                              return Text('$count', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.length == 1) {
      return GestureDetector(
        onTap: () => _showImageViewer(context, images, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: images.first,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox(),
          ),
        ),
      );
    }

    // 複数画像: グリッド表示
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showImageViewer(context, images, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: images[index],
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 160, height: 160,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
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
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 画像ビューア（ピンチズーム対応）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ImageViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageViewerScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.images.length > 1
            ? Text('${_currentIndex + 1} / ${widget.images.length}', style: const TextStyle(fontSize: 15))
            : null,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 空カード（共通） ──
Widget _buildEmptyCard(String message, IconData icon) {
  return SizedBox(
    height: 100,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: AppTheme.textHint),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );
}
