import 'dart:convert';
import '../profile/user_profile_screen.dart';
import '../notification/notification_screen.dart';
import '../../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  void _showFullImage(BuildContext context, ImageProvider imageProvider) {
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
                child: Image(image: imageProvider, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
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
                  Text('Sofvo',
                      style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 2,
                          color: AppTheme.textPrimary)),
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
                tabs: const [
                  Tab(text: 'タイムライン'),
                  Tab(text: 'お知らせ'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(),
                _buildNoticeTab(),
              ],
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .snapshots(),
      builder: (context, followSnapshot) {
        if (followSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primaryColor));
        }

        final followingIds = <String>[currentUser.uid];
        if (followSnapshot.data != null) {
          for (final doc in followSnapshot.data!.docs) {
            followingIds.add(doc.id);
          }
        }

        final queryIds = followingIds.take(30).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', whereIn: queryIds)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor));
            }

            if (postSnapshot.hasError) {
              debugPrint("TIMELINE ERROR: ${postSnapshot.error}");
              return _buildEmptyTimeline();
            }

            final posts = postSnapshot.data?.docs ?? [];
            if (posts.isEmpty) {
              return _buildEmptyTimeline();
            }

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async { setState(() {}); await Future.delayed(const Duration(milliseconds: 500)); },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 4, bottom: 80),
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, thickness: 1, color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final data =
                      posts[index].data() as Map<String, dynamic>;
                  return _buildPostItem(posts[index].id, data);
                },
              ),
            );
          },
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
              'フォロー中のユーザーの投稿がここに表示されます。\n「さがす」タブで仲間を見つけてフォローしましょう！',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.edit),
              label: const Text('最初の投稿をする'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
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
    final images = data['images'] is List ? List<String>.from(data['images']) : <String>[];
    final imageBase64 = data['imageBase64'] is List ? List<String>.from(data['imageBase64']) : <String>[];
    final likesCount = _safeInt(data['likesCount']);
    final commentsCount = _safeInt(data['commentsCount']);
    final createdAt = data['createdAt'] as Timestamp?;
    final timeText = _formatTime(createdAt);
    final List<ImageProvider> imageProviders = [];
    for (final url in images) {
      if (url.isNotEmpty) imageProviders.add(NetworkImage(url));
    }
    for (final b64 in imageBase64) {
      if (b64.isNotEmpty) {
        try { imageProviders.add(MemoryImage(base64Decode(b64))); } catch (_) {}
      }
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
                ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatarUrl),
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
                    const Spacer(),
                    _buildPostMenu(postId, isMyPost),
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.5)),
                ],
                if (imageProviders.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  imageProviders.length == 1
                      ? GestureDetector(
                          onTap: () => _showFullImage(context, imageProviders[0]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(image: imageProviders[0], width: double.infinity, height: 200, fit: BoxFit.cover),
                          ),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: imageProviders.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _showFullImage(context, imageProviders[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image(image: imageProviders[i], width: 160, height: 160, fit: BoxFit.cover),
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
                    const SizedBox(width: 32),
                    _buildStaticActionButton(Icons.share_outlined, ''),
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
                size: 18,
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
                        fontSize: 13,
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
              size: 18, color: AppTheme.textSecondary),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text('$count',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                            final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                            final uName = (uDoc.data()?['nickname'] as String?) ?? '名無し';
                            await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').add({
                              'userId': uid,
                              'userNickname': uName,
                              'text': txt,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            await FirebaseFirestore.instance.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});
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
    );
  }
  Widget _buildStaticActionButton(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        if (count.isNotEmpty && count != '0') ...[
          const SizedBox(width: 4),
          Text(count,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('報告を受け付けました。ご協力ありがとうございます。')),
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary),
                        title: const Text('この投稿を非表示'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('この投稿を非表示にしました')),
                          );
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

  Widget _buildNoticeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('アクティビティ',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _buildActivityNotice(
          icon: Icons.check_circle,
          color: AppTheme.success,
          title: 'エントリーが承認されました',
          body: '「第5回 世田谷カップ」へのエントリーが承認されました。大会詳細を確認しましょう。',
          time: '30分前',
          isUnread: true,
        ),
        const SizedBox(height: 10),
        _buildActivityNotice(
          icon: Icons.person_add,
          color: AppTheme.primaryColor,
          title: 'メンバー募集に応募がありました',
          body: 'ゆみさんが「春のソフトバレー大会」の募集に応募しました。',
          time: '2時間前',
          isUnread: true,
        ),
        const SizedBox(height: 10),
        _buildActivityNotice(
          icon: Icons.favorite,
          color: AppTheme.error,
          title: '投稿にいいねがつきました',
          body: 'たけしさん、けんたさんが あなたの投稿にいいねしました。',
          time: '5時間前',
          isUnread: false,
        ),
        const SizedBox(height: 10),
        _buildActivityNotice(
          icon: Icons.group_add,
          color: AppTheme.accentColor,
          title: 'フォローされました',
          body: 'あやかさんがあなたをフォローしました。',
          time: '1日前',
          isUnread: false,
        ),
        const SizedBox(height: 24),
        const Text('運営からのお知らせ',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _buildOfficialNotice(
          icon: Icons.campaign,
          color: AppTheme.accentColor,
          title: 'Sofvo 正式リリースのお知らせ',
          body: 'ソフトバレーボール マッチングアプリ「Sofvo」をご利用いただきありがとうございます。',
          time: '2026年2月14日',
        ),
        const SizedBox(height: 10),
        _buildOfficialNotice(
          icon: Icons.update,
          color: AppTheme.info,
          title: 'バージョン 1.1 アップデート',
          body: '大会検索のフィルター機能が強化されました。',
          time: '2026年2月10日',
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildActivityNotice({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread
            ? AppTheme.primaryColor.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4)),
                const SizedBox(height: 4),
                Text(time,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialNotice({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
        ],
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
