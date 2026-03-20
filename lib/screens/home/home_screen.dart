import 'dart:convert';
import '../profile/user_profile_screen.dart';
import '../notification/notification_screen.dart';
import '../../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../tournament/tournament_detail_screen.dart';
import '../tournament/post_event_action_screen.dart';
import '../follow/follow_search_screen.dart';
import 'create_post_screen.dart';
import 'comment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _hiddenPostIds = {};
  List<String>? _followingIds;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: const Duration(milliseconds: 200),
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // 並列でフォローリスト・非表示投稿・ユーザー情報を取得
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('users').doc(uid).collection('following').get(),
      FirebaseFirestore.instance
          .collection('users').doc(uid).collection('hiddenPosts').get(),
      FirebaseFirestore.instance
          .collection('users').doc(uid).get(),
    ]);
    if (!mounted) return;
    final followSnap = results[0];
    final hiddenSnap = results[1];
    final userDoc = results[2] as DocumentSnapshot;
    setState(() {
      _followingIds = [uid, ...followSnap.docs.map((d) => d.id)];
      _hiddenPostIds.addAll(hiddenSnap.docs.map((d) => d.id));
      _isAdmin = (userDoc.data() as Map<String, dynamic>?)?['isAdmin'] == true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == true) setState(() {});
  }

  void _showFullImage(BuildContext context, List<ImageProvider> images, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ── いいね切り替え ──
  Future<void> _toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.update({'likesCount': FieldValue.increment(1)});
      // いいね通知を送信
      final postDoc = await postRef.get();
      final postData = postDoc.data() as Map<String, dynamic>?;
      if (postData != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        final senderName = userData?['nickname'] ?? '不明';
        final senderAvatar = userData?['avatarUrl'] ?? '';
        NotificationService.sendLikeNotification(
          postOwnerId: postData['userId'] ?? '',
          senderId: uid,
          senderName: senderName,
          senderAvatar: senderAvatar,
          postId: postId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          // ━━━ 統一ヘッダー ━━━
          Material(
            color: Colors.white,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sof',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        TextSpan(
                          text: 'vo',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 2,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<int>(
                    stream: NotificationService.unreadCountStream(
                        FirebaseAuth.instance.currentUser?.uid ?? ''),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NotificationScreen())),
                        child: Stack(children: [
                          const Icon(Icons.notifications_outlined, size: 26, color: AppTheme.textPrimary),
                          if (count > 0)
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Text('$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                              ),
                            ),
                        ]),
                      );
                    },
                  ),
                ]),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                dividerColor: Colors.grey[200],
                tabs: [
                  const Tab(text: 'タイムライン'),
                  Tab(
                    child: _buildNoticeTabLabel(),
                  ),
                ],
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _KeepAlivePage(child: _buildTimelineTab()),
                _KeepAlivePage(child: _buildNoticeTab()),
              ],
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_create_post',
        onPressed: _openCreatePost,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildTimelineTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('ログインしてください'));
    }

    if (_followingIds == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    final queryIds = _followingIds!.take(30).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: queryIds)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) {
          debugPrint("TIMELINE ERROR: ${postSnapshot.error}");
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('データの取得に失敗しました',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    'ネットワーク接続を確認して\nもう一度お試しください',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('再読み込み'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (!postSnapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor));
        }

        final allPosts = postSnapshot.data?.docs ?? [];
        final posts = allPosts.where((doc) => !_hiddenPostIds.contains(doc.id)).toList();
        if (posts.isEmpty) {
          return _buildEmptyTimeline();
        }

        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await _loadInitialData();
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 80),
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, thickness: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final data =
                  posts[index].data() as Map<String, dynamic>? ?? {};
              return _buildPostItem(posts[index].id, data);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyTimeline() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('タイムラインに投稿がありません',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'フォロー中のユーザーの投稿がここに表示されます。\n仲間を見つけてフォローしましょう！',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCreatePost,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('投稿する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FollowSearchScreen()));
                },
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text('友達をさがす'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _badgeIconMap = <String, IconData>{
    '初参加': Icons.flag_rounded,
    '5大会参加': Icons.emoji_events_rounded,
    '10大会参加': Icons.emoji_events_rounded,
    '20大会参加': Icons.emoji_events_rounded,
    '初優勝': Icons.military_tech_rounded,
    '3回優勝': Icons.military_tech_rounded,
    '5回優勝': Icons.military_tech_rounded,
    '100Pt達成': Icons.star_rounded,
    '500Pt達成': Icons.star_rounded,
    '1000Pt達成': Icons.diamond_rounded,
    'ガジェット5個': Icons.devices_other_rounded,
    'フォロワー10': Icons.people_rounded,
    'フォロワー50': Icons.people_rounded,
    '投稿10件': Icons.article_rounded,
  };

  /// ネットワーク画像はCachedNetworkImageでプレースホルダー＋フェードイン表示
  Widget _buildFeedImage(List<String> urls, List<ImageProvider> base64Providers, int index, {double? width, double? height}) {
    if (index < urls.length) {
      return CachedNetworkImage(
        imageUrl: urls[index],
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))),
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
        memCacheWidth: width != null && width != double.infinity ? (width * 2).toInt() : 400,
        maxWidthDiskCache: 400,
        maxHeightDiskCache: 400,
      );
    }
    final b64Index = index - urls.length;
    return Image(image: base64Providers[b64Index], width: width, height: height, fit: BoxFit.cover);
  }

  /// フルスクリーン表示用にImageProvider一覧を構築
  List<ImageProvider> _buildAllProviders(List<String> urls, List<ImageProvider> base64Providers) {
    return [
      ...urls.map((u) => CachedNetworkImageProvider(u)),
      ...base64Providers,
    ];
  }

  Widget _buildBadgeCard(Map<String, dynamic> data) {
    final badgeName = data['badgeName'] as String? ?? '';
    final colorValue = (data['badgeColorValue'] as num?)?.toInt() ?? 0xFF4CAF50;
    final color = Color(colorValue);
    final icon = _badgeIconMap[badgeName] ?? Icons.emoji_events_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.10), color.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 2.5),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeName,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  'バッジ獲得！',
                  style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(Icons.verified, color: color, size: 26),
        ],
      ),
    );
  }

  Widget _buildAutoGeneratedPost(
    String postId, Map<String, dynamic> data, String text, String tournamentId,
    String nickname, String avatarUrl, String timeText,
    int likesCount, int commentsCount, Timestamp? createdAt,
    bool isMyPost, String? postUserId,
  ) {
    // テキストから大会名と優勝チーム名を抽出
    final nameMatch = RegExp(r'「(.+?)」').firstMatch(text);
    final tournamentName = nameMatch?.group(1) ?? '';
    final winnerMatch = RegExp(r'優勝: (.+)').firstMatch(text);
    final rawWinnerName = winnerMatch?.group(1)?.trim() ?? '';

    // 優勝チーム名がIDの場合、entriesから解決（FutureBuilderで非同期処理）
    final looksLikeId = rawWinnerName.isNotEmpty && RegExp(r'^[a-zA-Z0-9]{15,}$').hasMatch(rawWinnerName);

    if (looksLikeId) {
      return FutureBuilder<String>(
        future: _resolveTeamName(tournamentId, rawWinnerName),
        builder: (context, snapshot) {
          final resolvedName = snapshot.data ?? rawWinnerName;
          return _buildAutoGeneratedPostContent(
            postId, data, tournamentId, tournamentName, resolvedName,
            nickname, avatarUrl, timeText, likesCount, commentsCount, isMyPost, postUserId,
          );
        },
      );
    }

    return _buildAutoGeneratedPostContent(
      postId, data, tournamentId, tournamentName, rawWinnerName,
      nickname, avatarUrl, timeText, likesCount, commentsCount, isMyPost, postUserId,
    );
  }

  Future<String> _resolveTeamName(String tournamentId, String teamId) async {
    try {
      // まずdoc IDで直接取得
      final doc = await FirebaseFirestore.instance
          .collection('tournaments').doc(tournamentId)
          .collection('entries').doc(teamId).get();
      if (doc.exists) {
        final name = doc.data()?['teamName'] as String? ?? '';
        if (name.isNotEmpty) return name;
      }
      // teamIdフィールドで検索
      final query = await FirebaseFirestore.instance
          .collection('tournaments').doc(tournamentId)
          .collection('entries').where('teamId', isEqualTo: teamId).limit(1).get();
      if (query.docs.isNotEmpty) {
        final name = query.docs.first.data()['teamName'] as String? ?? '';
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return teamId;
  }

  Widget _buildAutoGeneratedPostContent(
    String postId, Map<String, dynamic> data, String tournamentId,
    String tournamentName, String winnerName,
    String nickname, String avatarUrl, String timeText,
    int likesCount, int commentsCount, bool isMyPost, String? postUserId,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー: 主催者情報
                Row(
                  children: [
                    avatarUrl.isNotEmpty
                        ? CircleAvatar(radius: 16, backgroundImage: CachedNetworkImageProvider(avatarUrl),
                            backgroundColor: Colors.grey.shade200)
                        : CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade200,
                            child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$nickname · $timeText',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                      ),
                      child: const Text('大会結果', style: TextStyle(color: AppTheme.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // トロフィーと大会名
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppTheme.accentColor, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tournamentName.isNotEmpty ? '「$tournamentName」終了！' : '大会終了！',
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                    ),
                  ],
                ),
                if (winnerName.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  // 優勝チーム名
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('優勝', style: TextStyle(color: AppTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(winnerName,
                          style: const TextStyle(color: AppTheme.accentColor, fontSize: 22, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text('ご参加ありがとうございました！',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                const SizedBox(height: 14),
                // 大会結果を見るボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final doc = await FirebaseFirestore.instance
                          .collection('tournaments').doc(tournamentId).get();
                      if (!doc.exists || !mounted) return;
                      final tData = doc.data()!;
                      tData['id'] = doc.id;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TournamentDetailScreen(tournament: tData, initialTab: 'standings'),
                      ));
                    },
                    icon: const Icon(Icons.emoji_events, size: 16),
                    label: const Text('大会結果を見る'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // いいね・コメントバー
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Row(
              children: [
                _buildLikeButton(postId, likesCount),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showCommentSheet(postId, nickname),
                  child: Row(children: [
                    Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('$commentsCount', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                  ]),
                ),
                const Spacer(),
                if (isMyPost) _buildPostMenu(postId, isMyPost),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(String postId, Map<String, dynamic> data) {
    final avatarUrl = _safeString(data['userAvatarUrl'], '');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final postUserId = data['userId'] as String?;
    final isMyPost = currentUserId != null && postUserId == currentUserId;
    final nickname = _safeString(data['userNickname'], '名無し');
    final text = _safeString(data['text'], '');
    final tournamentId = data['tournamentId'] as String?;
    final isAutoGenerated = data['autoGenerated'] == true;
    final images = data['images'] is List ? List<String>.from(data['images']) : <String>[];
    final imageBase64 = data['imageBase64'] is List ? List<String>.from(data['imageBase64']) : <String>[];
    final likesCount = _safeInt(data['likesCount']);
    final commentsCount = _safeInt(data['commentsCount']);
    final createdAt = data['createdAt'] as Timestamp?;
    final timeText = _formatTime(createdAt);
    final hasBadge = data['badgeName'] != null;
    // 画像URL一覧（ネットワーク画像 + base64画像をImageProviderとして保持）
    final List<String> imageUrls = images.where((u) => u.isNotEmpty).toList();
    final List<ImageProvider> base64Providers = [];
    for (final b64 in imageBase64) {
      if (b64.isNotEmpty) {
        try { base64Providers.add(MemoryImage(base64Decode(b64))); } catch (_) {}
      }
    }
    final int totalImages = imageUrls.length + base64Providers.length;

    // 自動生成投稿（大会結果）の場合は特別なUI
    if (isAutoGenerated && tournamentId != null && tournamentId.isNotEmpty) {
      return _buildAutoGeneratedPost(postId, data, text, tournamentId, nickname, avatarUrl, timeText, likesCount, commentsCount, createdAt, isMyPost, postUserId);
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              debugPrint("Avatar tapped! postUserId=$postUserId");
              if (postUserId != null && postUserId.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: postUserId!),
                ));
              }
            },
            child: avatarUrl.isNotEmpty
                ? CircleAvatar(radius: 22, backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15))
                : CircleAvatar(radius: 22, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          if (postUserId != null && postUserId.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: postUserId),
                            ));
                          }
                        },
                        child: Text(nickname,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('· $timeText', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.5)),
                ],
                if (tournamentId != null && tournamentId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final doc = await FirebaseFirestore.instance
                          .collection('tournaments').doc(tournamentId).get();
                      if (!doc.exists || !mounted) return;
                      final tData = doc.data()!;
                      tData['id'] = doc.id;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TournamentDetailScreen(tournament: tData, initialTab: 'standings'),
                      ));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, size: 16, color: AppTheme.primaryColor),
                          SizedBox(width: 6),
                          Text('大会結果を見る',
                            style: TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
                if (hasBadge) ...[
                  const SizedBox(height: 10),
                  _buildBadgeCard(data),
                ],
                if (totalImages > 0) ...[
                  const SizedBox(height: 10),
                  totalImages == 1
                      ? GestureDetector(
                          onTap: () => _showFullImage(context, _buildAllProviders(imageUrls, base64Providers), 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildFeedImage(imageUrls, base64Providers, 0, width: double.infinity, height: 200),
                          ),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: totalImages,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _showFullImage(context, _buildAllProviders(imageUrls, base64Providers), i),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildFeedImage(imageUrls, base64Providers, i, width: 160, height: 160),
                              ),
                            ),
                          ),
                        ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildCommentButton(postId, commentsCount, nickname),
                    const SizedBox(width: 32),
                    _buildLikeButton(postId, likesCount),
                    const Spacer(),
                    _buildPostMenu(postId, isMyPost),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── いいねボタン（リアルタイム） ──
  Widget _buildLikeButton(String postId, int fallbackCount) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildStaticActionButton(Icons.favorite_border, '$fallbackCount');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(uid)
          .snapshots(),
      builder: (context, likeSnapshot) {
        final isLiked = likeSnapshot.data?.exists ?? false;

        return GestureDetector(
          onTap: () => _toggleLike(postId),
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: isLiked ? Colors.red : AppTheme.textSecondary,
              ),
              if (fallbackCount > 0 || isLiked) ...[
                const SizedBox(width: 4),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .snapshots(),
                  builder: (context, postSnap) {
                    final count = postSnap.data?.get('likesCount') ?? fallbackCount;
                    return Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        color: isLiked ? Colors.red : AppTheme.textSecondary,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── コメントボタン（後で実装） ──
  Widget _buildCommentButton(String postId, int count, String postOwnerName) {
    return GestureDetector(
      onTap: () => _showCommentSheet(postId, postOwnerName),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 22, color: AppTheme.textSecondary),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text('$count',
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  void _showCommentSheet(String postId, String postOwnerName) {
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
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('コメント',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('comments')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
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
                          final t = _formatTime(ts);
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
                                            await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').doc(cId).delete();
                                            await FirebaseFirestore.instance.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(-1)});
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
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(24),
                            ),
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
                              final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                              final uName = (uDoc.data()?['nickname'] as String?) ?? '名無し';
                              await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').add({
                                'userId': uid,
                                'userNickname': uName,
                                'text': txt,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              await FirebaseFirestore.instance.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});
                            } catch (_) {
                              // Silently handle - comment will not appear but app won't crash
                            }
                          },
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
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
  Widget _buildStaticActionButton(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.textSecondary),
        if (count.isNotEmpty && count != '0') ...[
          const SizedBox(width: 4),
          Text(count,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ],
    );
  }

  Widget _buildPostMenu(String postId, bool isMyPost) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (isMyPost) ...[
                      ListTile(
                        leading: const Icon(Icons.delete_outline,
                            color: AppTheme.error),
                        title: const Text('投稿を削除',
                            style: TextStyle(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDeletePostDialog(postId);
                        },
                      ),
                    ],
                    if (!isMyPost) ...[
                      ListTile(
                        leading: Icon(Icons.flag_outlined,
                            color: AppTheme.textSecondary),
                        title: const Text('この投稿を報告'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _reportPost(postId);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary),
                        title: const Text('この投稿を非表示'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _hidePost(postId);
                        },
                      ),
                    ],
                    ListTile(
                      leading: Icon(Icons.close,
                          color: AppTheme.textSecondary),
                      title: const Text('キャンセル'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.more_horiz,
            size: 20, color: AppTheme.textSecondary),
      ),
    );
  }

  Future<void> _reportPost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final reasons = [
      'スパム・迷惑行為',
      '不適切なコンテンツ',
      'なりすまし',
      'ハラスメント',
      'その他',
    ];

    final selectedReason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('報告の理由を選択',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...reasons.map((reason) => ListTile(
                    title: Text(reason),
                    onTap: () => Navigator.pop(ctx, reason),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selectedReason == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'postId': postId,
        'reporterId': uid,
        'reason': selectedReason,
        'type': 'post',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を受け付けました。ご協力ありがとうございます。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('報告に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _hidePost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('hiddenPosts').doc(postId)
          .set({'hiddenAt': FieldValue.serverTimestamp()});
      setState(() => _hiddenPostIds.add(postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この投稿を非表示にしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('非表示に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showDeletePostDialog(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('投稿を削除',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
            'この投稿を削除しますか？\nこの操作は取り消せません。',
            style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('投稿を削除しました'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('削除に失敗しました: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeTabLabel() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text('お知らせ');
    return StreamBuilder<int>(
      stream: NotificationService.unreadAnnouncementCountStream(uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('お知らせ'),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNoticeTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, noticesSnap) {
        // ユーザー個人の大会・システム通知
        if (uid == null) {
          return _buildNoticeList(noticesSnap, null);
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .where('type', whereIn: NotificationService.announcementTypes)
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots(),
          builder: (context, personalSnap) {
            return _buildNoticeList(noticesSnap, personalSnap);
          },
        );
      },
    ),
        if (_isAdmin)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'admin_notice',
              onPressed: _showCreateNoticeDialog,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.campaign, size: 20),
              label: const Text('配信'),
            ),
          ),
      ],
    );
  }

  static const _noticeTemplates = <String, List<Map<String, String>>>{
    'info': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': 'イベント告知', 'title': 'イベントのお知らせ', 'body': '下記の日程でイベントを開催します。\n\n日時: \n場所: \n内容: \n\n皆様のご参加をお待ちしております！'},
      {'label': 'ルール変更', 'title': 'ルール変更のお知らせ', 'body': '以下のルールが変更されました。\n\n【変更点】\n・\n\n【適用日】\n\nご不明点があればお問い合わせください。'},
    ],
    'release': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': '新機能リリース', 'title': '新機能リリースのお知らせ', 'body': '新しい機能が追加されました！\n\n【新機能】\n・\n\nぜひお試しください！'},
      {'label': '正式リリース', 'title': 'Sofvo 正式リリースのお知らせ', 'body': 'ソフトバレーボール マッチングアプリ「Sofvo」をご利用いただきありがとうございます。大会検索・メンバー募集・チャットなどの機能をお楽しみください。'},
    ],
    'update': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': 'アップデート', 'title': 'バージョン アップデート', 'body': '以下の機能が改善されました。\n\n【改善点】\n・\n\nアプリを最新版に更新してご利用ください。'},
      {'label': '不具合修正', 'title': '不具合修正のお知らせ', 'body': '以下の不具合を修正しました。\n\n【修正内容】\n・\n\nご不便をおかけして申し訳ございませんでした。'},
    ],
    'maintenance': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': '定期メンテナンス', 'title': 'メンテナンスのお知らせ', 'body': '下記の日時にメンテナンスを実施します。\n\n日時: 月 日（ ） 00:00 〜 00:00\n\nメンテナンス中はサービスをご利用いただけません。ご迷惑をおかけしますが、ご了承ください。'},
      {'label': '緊急メンテナンス', 'title': '緊急メンテナンスのお知らせ', 'body': '現在、緊急メンテナンスを実施中です。\n\n復旧予定: 月 日（ ） 00:00\n\nご不便をおかけして申し訳ございません。復旧次第お知らせいたします。'},
    ],
  };

  Future<void> _showCreateNoticeDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = 'info';
    int selectedTemplateIndex = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final templates = _noticeTemplates[selectedType] ?? _noticeTemplates['info']!;

          void applyTemplate(int index) {
            selectedTemplateIndex = index;
            final t = templates[index];
            titleController.text = t['title'] ?? '';
            bodyController.text = t['body'] ?? '';
          }

          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('お知らせを配信',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('種類', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _noticeTypeChip('info', 'お知らせ', Icons.info_outline, AppTheme.primaryColor, selectedType, (v) {
                      setDialogState(() { selectedType = v; selectedTemplateIndex = 0; });
                      applyTemplate(0);
                    }),
                    _noticeTypeChip('release', 'リリース', Icons.campaign, AppTheme.accentColor, selectedType, (v) {
                      setDialogState(() { selectedType = v; selectedTemplateIndex = 0; });
                      applyTemplate(0);
                    }),
                    _noticeTypeChip('update', '更新', Icons.update, AppTheme.info, selectedType, (v) {
                      setDialogState(() { selectedType = v; selectedTemplateIndex = 0; });
                      applyTemplate(0);
                    }),
                    _noticeTypeChip('maintenance', 'メンテ', Icons.build, AppTheme.warning, selectedType, (v) {
                      setDialogState(() { selectedType = v; selectedTemplateIndex = 0; });
                      applyTemplate(0);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('テンプレート', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: List.generate(templates.length, (i) {
                    final isSelected = i == selectedTemplateIndex;
                    return ChoiceChip(
                      label: Text(templates[i]['label']!),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setDialogState(() => applyTemplate(i)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  decoration: InputDecoration(
                    labelText: '本文',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('タイトルと本文を入力してください'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('配信する'),
            ),
          ],
        );
        },
      ),
    );

    if (result == true) {
      await FirebaseFirestore.instance.collection('notices').add({
        'type': selectedType,
        'title': titleController.text.trim(),
        'body': bodyController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お知らせを配信しました'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _noticeTypeChip(String value, String label, IconData icon, Color color, String selected, ValueChanged<String> onSelect) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onSelect(value),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildNoticeList(
    AsyncSnapshot<QuerySnapshot> noticesSnap,
    AsyncSnapshot<QuerySnapshot>? personalSnap,
  ) {
    if (noticesSnap.hasError || (personalSnap?.hasError ?? false)) {
      return Center(
          child: Text('読み込みに失敗しました',
              style: TextStyle(color: AppTheme.textSecondary)));
    }
    if (!noticesSnap.hasData || (personalSnap != null && !personalSnap.hasData)) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    // 統合リストを構築
    final items = <_NoticeItem>[];

    // グローバルお知らせ
    for (final doc in noticesSnap.data?.docs ?? []) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = data['type'] ?? 'info';
      final createdAt = data['createdAt'] as Timestamp?;

      IconData icon;
      Color color;
      switch (type) {
        case 'release':
          icon = Icons.campaign;
          color = AppTheme.accentColor;
          break;
        case 'update':
          icon = Icons.update;
          color = AppTheme.info;
          break;
        case 'maintenance':
          icon = Icons.build;
          color = AppTheme.warning;
          break;
        default:
          icon = Icons.info_outline;
          color = AppTheme.primaryColor;
      }

      items.add(_NoticeItem(
        icon: icon,
        color: color,
        title: data['title'] ?? '',
        body: data['body'] ?? '',
        time: _formatTime(createdAt),
        createdAt: createdAt,
        isRead: true, // グローバルお知らせは既読管理なし
      ));
    }

    // 個人の大会・システム通知
    for (final doc in personalSnap?.data?.docs ?? []) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final type = data['type'] ?? '';
      final createdAt = data['createdAt'] as Timestamp?;
      final bool isRead = data['read'] ?? true;

      IconData icon;
      Color color;
      String title;
      String body;

      switch (type) {
        case 'tournament_announcement':
          icon = Icons.campaign;
          color = AppTheme.accentColor;
          title = '大会お知らせ';
          body = data['message'] ?? '';
          break;
        case 'tournament_end':
          icon = Icons.emoji_events;
          color = AppTheme.accentColor;
          title = '大会終了';
          body = data['message'] ?? '';
          break;
        case 'waitlist_available':
          icon = Icons.how_to_reg;
          color = AppTheme.success;
          title = 'キャンセル待ち';
          body = data['message'] ?? '';
          break;
        case 'points_earned':
          icon = Icons.star_rounded;
          color = AppTheme.accentColor;
          title = 'ポイント獲得';
          body = data['message'] ?? '';
          break;
        default:
          icon = Icons.info_outline;
          color = AppTheme.primaryColor;
          title = 'お知らせ';
          body = data['message'] ?? '';
      }

      items.add(_NoticeItem(
        icon: icon,
        color: color,
        title: title,
        body: body,
        time: _formatTime(createdAt),
        createdAt: createdAt,
        isRead: isRead,
        data: data,
        docId: doc.id,
      ));
    }

    // 日時で降順ソート
    items.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('お知らせはありません',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // 開いた時点で個人お知らせを既読に
    _markAnnouncementsAsRead();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildOfficialNotice(
            icon: item.icon,
            color: item.color,
            title: item.title,
            body: item.body,
            time: item.time,
            isRead: item.isRead,
            onTap: item.data != null ? () => _onAnnouncementTap(item.data!) : null,
          ),
        );
      },
    );
  }

  Future<void> _markAnnouncementsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final unread = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .where('type', whereIn: NotificationService.announcementTypes)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _onAnnouncementTap(Map<String, dynamic> data) async {
    final type = data['type'] ?? '';
    final tournamentId = data['tournamentId'] as String?;

    if (type == 'tournament_end' &&
        tournamentId != null &&
        tournamentId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournamentId)
            .get();
        if (!doc.exists || !mounted) return;
        final tData = doc.data() ?? {};
        final tournamentName =
            (tData['title'] ?? tData['name'] ?? '') as String;

        String? myResult;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final entries = await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournamentId)
              .collection('entries')
              .get();
          for (final entry in entries.docs) {
            final memberUids = entry.data()['memberUids'] as List?;
            if (memberUids != null && memberUids.contains(uid)) {
              final rank = entry.data()['finalRank'];
              if (rank is int) {
                if (rank == 1) myResult = '優勝';
                else if (rank == 2) myResult = '準優勝';
                else if (rank == 3) myResult = '3位';
                else myResult = '$rank位';
              }
              break;
            }
          }
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostEventActionScreen(
              tournamentId: tournamentId,
              tournamentName: tournamentName,
              result: myResult,
            ),
          ),
        );
      } catch (e) {
        debugPrint('ふりかえり画面遷移に失敗: $e');
      }
      return;
    }

    if ((type == 'tournament_announcement' ||
            type == 'waitlist_available' ||
            type == 'points_earned') &&
        tournamentId != null &&
        tournamentId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournamentId)
            .get();
        if (!doc.exists || !mounted) return;
        final tData = doc.data() ?? {};
        tData['id'] = doc.id;
        tData['name'] = tData['title'] ?? tData['name'] ?? '';
        final initialTab =
            type == 'tournament_announcement' ? 'board' : null;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentDetailScreen(
              tournament: tData,
              initialTab: initialTab,
            ),
          ),
        );
      } catch (e) {
        debugPrint('大会遷移に失敗: $e');
      }
    }
  }

  Widget _buildOfficialNotice({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required String time,
    bool isRead = true,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.primaryColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.grey[200]! : AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  String _safeString(dynamic value, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    return fallback;
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'たった今';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    return '${date.month}/${date.day}';
  }
}

// ── X風フルスクリーン画像ビューア ──
class _FullScreenImageViewer extends StatefulWidget {
  final List<ImageProvider> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  double _verticalDrag = 0;
  double _opacity = 1.0;

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

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _verticalDrag += details.delta.dy;
      _opacity = (1 - (_verticalDrag.abs() / 300)).clamp(0.3, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_verticalDrag.abs() > 100) {
      Navigator.pop(context);
    } else {
      setState(() {
        _verticalDrag = 0;
        _opacity = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: _opacity),
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            // 画像 PageView
            Transform.translate(
              offset: Offset(0, _verticalDrag),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image(
                      image: widget.images[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            // 閉じるボタン
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            // ページインジケーター (2枚以上の場合のみ)
            if (widget.images.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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

/// お知らせタブで使う統合アイテム
class _NoticeItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final Timestamp? createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;
  final String? docId;

  _NoticeItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.createdAt,
    this.isRead = true,
    this.data,
    this.docId,
  });
}
