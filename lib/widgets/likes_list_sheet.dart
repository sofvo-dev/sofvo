import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_theme.dart';
import '../services/follow_service.dart';
import '../services/notification_service.dart';
import '../screens/profile/user_profile_screen.dart';

/// 投稿にいいねした人の一覧を下からのボトムシートで表示する。
/// いいね数（数字）タップから呼び出す。ハート自体のON/OFFとは別導線。
Future<void> showLikesSheet(
  BuildContext context, {
  required String postId,
  int likesCount = 0,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _LikesListSheet(postId: postId, likesCount: likesCount),
  );
}

class _LikesListSheet extends StatelessWidget {
  const _LikesListSheet({required this.postId, required this.likesCount});

  final String postId;
  final int likesCount;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.74;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // グリップ
          Container(
            width: 38,
            height: 5,
            margin: const EdgeInsets.only(top: 9, bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD3D7DD),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          // ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('likes')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.hasData ? snap.data!.docs.length : likesCount;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite, color: Color(0xFFE0245E), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'いいね $count',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF0F2)),
          // リスト本体
          Flexible(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('likes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('まだいいねはありません',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  );
                }
                final uids = docs.map((d) => d.id).toList();
                return ListView.builder(
                  padding: EdgeInsets.only(
                      top: 4,
                      bottom: 14 + MediaQuery.of(context).padding.bottom),
                  itemCount: uids.length,
                  itemBuilder: (context, i) => _LikeUserRow(uid: uids[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// いいねした1人分の行。ユーザー情報を読み込み、フォローボタン／プロフィール遷移を提供する。
class _LikeUserRow extends StatefulWidget {
  const _LikeUserRow({required this.uid});
  final String uid;

  @override
  State<_LikeUserRow> createState() => _LikeUserRowState();
}

class _LikeUserRowState extends State<_LikeUserRow> {
  bool _toggling = false;
  late final Future<DocumentSnapshot> _userFuture = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.uid)
      .get();

  Future<void> _toggleFollow(String nickname) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _toggling) return;
    final wasFollowing = FollowService.instance.isFollowing(widget.uid);

    setState(() => _toggling = true);
    try {
      String myNickname = '不明';
      String myAvatarUrl = '';
      if (!wasFollowing) {
        final myDoc =
            await FirebaseFirestore.instance.collection('users').doc(myUid).get();
        final myData = myDoc.data() ?? {};
        myNickname = (myData['nickname'] as String?) ?? '不明';
        myAvatarUrl = (myData['avatarUrl'] as String?) ?? '';
      }

      await FollowService.instance
          .toggleFollow(targetUid: widget.uid, targetNickname: nickname);

      if (!wasFollowing) {
        NotificationService.sendFollowNotification(
          targetUserId: widget.uid,
          senderId: myUid,
          senderName: myNickname,
          senderAvatar: myAvatarUrl,
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid == widget.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final nickname = (data['nickname'] as String?)?.trim();
        final displayName = (nickname == null || nickname.isEmpty) ? 'ユーザー' : nickname;
        final avatarUrl = (data['avatarUrl'] as String?) ?? '';
        final searchId = (data['searchId'] as String?) ?? '';
        final rawArea = data['area'];
        final area = rawArea is String
            ? rawArea
            : (rawArea is Map ? (rawArea['prefecture'] ?? '').toString() : '');

        final metaParts = <String>[
          if (searchId.isNotEmpty) '@$searchId',
          if (area.isNotEmpty) area,
        ];

        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: widget.uid),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: AppTheme.primaryColor, size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          metaParts.join(' ・ '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isMe)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('自分',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  )
                else
                  AnimatedBuilder(
                    animation: FollowService.instance,
                    builder: (context, _) {
                      final following =
                          FollowService.instance.isFollowing(widget.uid);
                      return _FollowButton(
                        following: following,
                        busy: _toggling,
                        onTap: () => _toggleFollow(displayName),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.busy,
    required this.onTap,
  });

  final bool following;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: following
          ? OutlinedButton(
              onPressed: busy ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('フォロー中',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            )
          : OutlinedButton(
              onPressed: busy ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('フォローする',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
    );
  }
}
