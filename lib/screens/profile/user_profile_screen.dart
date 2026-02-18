import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
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

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isMyProfile => widget.userId == _currentUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
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
                        onPressed: () {
                          // TODO: DMへ遷移
                        },
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
}
