import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final String title; // 'フォロワー' or 'フォロー中'
  final bool isFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.isFollowers,
  });

  @override
  Widget build(BuildContext context) {
    final collection = isFollowers ? 'followers' : 'following';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(collection)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // インデックスなしフォールバック
          if (snapshot.hasError) {
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection(collection)
                  .get(),
              builder: (context, futureSnap) {
                if (futureSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = futureSnap.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmpty();
                return _buildList(context, docs);
              },
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmpty();
          return _buildList(context, docs);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            isFollowers ? 'まだフォロワーがいません' : 'まだ誰もフォローしていません',
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final targetUid = docs[index].id;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }

            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final nickname = userData['nickname'] ?? '名前なし';
            final avatarUrl = userData['avatarUrl'] ?? '';
            final bio = userData['bio'] ?? '';
            final area = userData['area'] ?? '';

            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: targetUid),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    avatarUrl.toString().isNotEmpty
                        ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl),
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.1))
                        : CircleAvatar(radius: 24, backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                            child: Text(nickname.toString().isNotEmpty ? nickname.toString()[0] : '?',
                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nickname.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          if (area.toString().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.location_on, size: 13, color: AppTheme.textHint),
                              const SizedBox(width: 3),
                              Text(area.toString(), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ]),
                          ],
                          if (bio.toString().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(bio.toString(), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textHint),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
