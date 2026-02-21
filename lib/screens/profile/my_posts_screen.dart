import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 自分の投稿一覧画面
class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('自分の投稿')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('自分の投稿')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final posts = snapshot.data?.docs ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('まだ投稿がありません',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              final text = (data['text'] ?? '') as String;
              final createdAt = data['createdAt'] as Timestamp?;
              final images = data['images'] is List
                  ? List<String>.from(data['images'])
                  : <String>[];
              final imageBase64 = data['imageBase64'] is List
                  ? List<String>.from(data['imageBase64'])
                  : <String>[];
              final likesCount = (data['likesCount'] ?? 0) as int;
              final commentsCount = (data['commentsCount'] ?? 0) as int;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      Text(text,
                          style: const TextStyle(
                              fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
                    if (images.isNotEmpty || imageBase64.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...images.where((u) => u.isNotEmpty).map((url) =>
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(url,
                                      width: 120, height: 120, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            ...imageBase64.where((b) => b.isNotEmpty).map((b64) {
                              try {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(base64Decode(b64),
                                        width: 120, height: 120, fit: BoxFit.cover),
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox();
                              }
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.favorite_outline, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('$likesCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(width: 16),
                        Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('$commentsCount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const Spacer(),
                        if (createdAt != null)
                          Text(_formatDate(createdAt),
                              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
