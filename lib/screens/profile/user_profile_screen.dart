import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  int _followingCount = 0;
  int _followersCount = 0;
  int _postsCount = 0;
  List<Map<String, dynamic>> _tournamentHistory = [];
  List<Map<String, dynamic>> _gadgets = [];

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isMyProfile => widget.userId == _currentUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _loadTournamentHistory();
    _loadGadgets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userDoc = await _firestore.collection('users').doc(widget.userId).get();
    final userData = userDoc.data() ?? {};

    final followingSnap = await _firestore
        .collection('users').doc(widget.userId).collection('following').get();
    final followersSnap = await _firestore
        .collection('users').doc(widget.userId).collection('followers').get();
    final postsSnap = await _firestore
        .collection('posts').where('userId', isEqualTo: widget.userId).get();

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
        _postsCount = postsSnap.docs.length;
        _isFollowing = isFollowing;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTournamentHistory() async {
    final tournSnap = await _firestore.collection('tournaments').get();
    final history = <Map<String, dynamic>>[];

    for (final doc in tournSnap.docs) {
      final data = doc.data();
      final isOrganizer = data['organizerId'] == widget.userId;
      final entriesSnap = await doc.reference
          .collection('entries')
          .where('enteredBy', isEqualTo: widget.userId)
          .limit(1)
          .get();
      final isEntered = entriesSnap.docs.isNotEmpty;
      if (!isOrganizer && !isEntered) continue;

      final status = data['status'] ?? '準備中';
      if (status != '終了') continue;

      history.add({
        ...data,
        'id': doc.id,
        'teamName': isEntered
            ? (entriesSnap.docs.first.data()['teamName'] ?? '')
            : '主催者',
        'isOrganizer': isOrganizer,
      });
    }
    history.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

    if (mounted) setState(() => _tournamentHistory = history.take(5).toList());
  }

  Future<void> _loadGadgets() async {
    final snap = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('gadgets')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      setState(() {
        _gadgets = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
  }

  Future<void> _startDmWith(String otherUid, String otherName) async {
    final myUid = _currentUid;
    if (myUid.isEmpty) return;

    // 既存DMを検索
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

    // なければ新規作成
    if (chatId == null) {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myName = (myDoc.data()?['nickname'] as String?) ?? '自分';

      final ref = await _firestore.collection('chats').add({
        'type': 'dm',
        'members': [myUid, otherUid],
        'memberNames': {myUid: myName, otherUid: otherName},
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
      await myRef.collection('following').doc(widget.userId).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
      await targetRef.collection('followers').doc(_currentUid).set({
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final nickname = _userData['nickname'] ?? '名前なし';
    final bio = _userData['bio'] ?? '';
    final avatarUrl = _userData['avatarUrl'] ?? '';
    final area = _userData['area'] ?? '';
    final experience = _userData['experience'] ?? '';
    final odId = _userData['odId'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(nickname, style: const TextStyle(fontSize: 16)),
        actions: [
          if (!_isMyProfile)
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: _showBlockReportSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // プロフィールヘッダー
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    avatarUrl.toString().isNotEmpty
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(avatarUrl),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          )
                        : CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Text(
                              nickname.toString().isNotEmpty ? nickname.toString()[0] : '?',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn('投稿', _postsCount, null),
                          _buildStatColumn('フォロワー', _followersCount, () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(userId: widget.userId, title: 'フォロワー', isFollowers: true),
                            ));
                          }),
                          _buildStatColumn('フォロー中', _followingCount, () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(userId: widget.userId, title: 'フォロー中', isFollowers: false),
                            ));
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      if (odId.toString().isNotEmpty)
                        Text('@$odId', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      if (area.toString().isNotEmpty || experience.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          if (area.toString().isNotEmpty) ...[
                            Icon(Icons.location_on, size: 14, color: AppTheme.textHint),
                            const SizedBox(width: 2),
                            Text(area.toString(), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(width: 12),
                          ],
                          if (experience.toString().isNotEmpty) ...[
                            Icon(Icons.sports_volleyball, size: 14, color: AppTheme.textHint),
                            const SizedBox(width: 2),
                            Text(experience.toString(), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ]),
                      ],
                      if (bio.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(bio.toString(), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!_isMyProfile)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.grey[200] : AppTheme.primaryColor,
                            foregroundColor: _isFollowing ? AppTheme.textPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          child: Text(_isFollowing ? 'フォロー中' : 'フォローする',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _startDmWith(widget.userId, nickname),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('メッセージ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // ━━━ 戦績サマリー ━━━
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              _buildProfileStatCard(Icons.star, '通算Pt',
                  '${_userData['totalPoints'] ?? 0}', AppTheme.accentColor),
              const SizedBox(width: 8),
              _buildProfileStatCard(
                  Icons.emoji_events,
                  '参加',
                  '${(_userData['stats'] as Map<String, dynamic>?)?['tournamentsPlayed'] ?? 0}',
                  AppTheme.primaryColor),
              const SizedBox(width: 8),
              _buildProfileStatCard(
                  Icons.military_tech,
                  '優勝',
                  '${(_userData['stats'] as Map<String, dynamic>?)?['championships'] ?? 0}',
                  AppTheme.warning),
            ]),
          ),
          // タブバー
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: '投稿'),
                Tab(text: '所属チーム'),
                Tab(text: '戦績'),
              ],
            ),
          ),
          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildTeamsTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ━━━ 投稿タブ ━━━
  Widget _buildPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // インデックスなしフォールバック
          return FutureBuilder<QuerySnapshot>(
            future: _firestore.collection('posts')
                .where('userId', isEqualTo: widget.userId).get(),
            builder: (context, futureSnap) {
              if (futureSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final posts = futureSnap.data?.docs ?? [];
              if (posts.isEmpty) return _buildEmptyState('まだ投稿がありません', Icons.article_outlined);
              return _buildPostList(posts);
            },
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) return _buildEmptyState('まだ投稿がありません', Icons.article_outlined);
        return _buildPostList(posts);
      },
    );
  }

  Widget _buildPostList(List<QueryDocumentSnapshot> posts) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final data = posts[index].data() as Map<String, dynamic>;
        final text = data['text'] ?? '';
        final images = data['images'] is List ? List<String>.from(data['images']) : <String>[];
        final likesCount = data['likesCount'] ?? 0;
        final commentsCount = data['commentsCount'] ?? 0;
        final createdAt = data['createdAt'] as Timestamp?;
        final timeAgo = _formatTimeAgo(createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.toString(), style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(images.first, height: 180, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('$likesCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(width: 16),
                  Icon(Icons.comment, size: 16, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('$commentsCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const Spacer(),
                  Text(timeAgo, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ━━━ チームタブ ━━━
  Widget _buildTeamsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('teams')
          .where('memberIds', arrayContains: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = snapshot.data?.docs ?? [];
        if (teams.isEmpty) return _buildEmptyState('所属チームはありません', Icons.groups_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final data = teams[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'チーム';
            final memberNames = data['memberNames'] is Map
                ? Map<String, String>.from(data['memberNames'])
                : <String, String>{};
            final isOwner = data['ownerId'] == widget.userId;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(name.toString()[0],
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${memberNames.length}人 ${isOwner ? "・オーナー" : "・メンバー"}',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('オーナー', style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        ],
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

  Widget _buildProfileStatCard(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  // ━━━ 戦績タブ ━━━
  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 過去の大会
        if (_tournamentHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('過去の大会',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          ..._tournamentHistory.map((t) => _buildHistoryCard(t)),
          const SizedBox(height: 16),
        ],
        // 使用アイテム
        if (_gadgets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('使用アイテム',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          ..._gadgets.map((g) => _buildGadgetCard(g)),
        ],
        if (_tournamentHistory.isEmpty && _gadgets.isEmpty)
          _buildEmptyState('戦績はまだありません', Icons.emoji_events_outlined),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> t) {
    final dateStr = t['date'] ?? '';
    String dateDisplay = dateStr;
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 3) {
        dateDisplay = '${int.parse(parts[1])}/${parts[2]}';
      }
    } catch (_) {}
    final isOrganizer = t['isOrganizer'] == true;

    return GestureDetector(
      onTap: () {
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
                'status': t['status'] ?? '終了',
                'statusColor': AppTheme.textSecondary,
                'deadline': '',
                'organizer': t['organizerName'] ?? '',
                'isFollowing': true,
                'organizerId': t['organizerId'] ?? '',
                'rules': t['rules'] ?? {},
                'venueAddress': t['venueAddress'] ?? '',
                'location': t['location'] ?? '',
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(dateDisplay,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text(t['location'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isOrganizer
                          ? AppTheme.accentColor.withValues(alpha: 0.1)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isOrganizer ? '主催' : '出場',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOrganizer
                                ? AppTheme.accentColor
                                : AppTheme.primaryColor)),
                  ),
                ]),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Widget _buildGadgetCard(Map<String, dynamic> gadget) {
    final name = gadget['name'] ?? '';
    final category = gadget['category'] ?? '';
    final imageUrl = gadget['imageUrl'] ?? '';
    final amazonUrl = gadget['amazonUrl'] ?? '';
    final rakutenUrl = gadget['rakutenUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag_outlined,
                          size: 24,
                          color: Colors.grey[400])),
                )
              : Icon(Icons.shopping_bag_outlined,
                  size: 24, color: Colors.grey[400]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (category.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(category,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                if (amazonUrl.isNotEmpty)
                  _buildShopBtn('Amazon', AppTheme.accentColor, amazonUrl),
                if (amazonUrl.isNotEmpty && rakutenUrl.isNotEmpty)
                  const SizedBox(width: 6),
                if (rakutenUrl.isNotEmpty)
                  _buildShopBtn('楽天', AppTheme.error, rakutenUrl),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildShopBtn(String label, Color color, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
