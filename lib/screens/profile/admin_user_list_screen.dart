import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../../widgets/official_badge.dart';
import 'user_profile_screen.dart';
import '../admin/admin_user_detail_screen.dart';

/// 全登録ユーザー一覧（管理者用）
class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('全登録ユーザー', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 検索バー
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'ユーザー名で検索',
                hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // ユーザー数
          StreamBuilder<AggregateQuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .count()
                .get()
                .asStream(),
            builder: (context, snap) {
              final count = snap.data?.count ?? 0;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Text(
                  '全 $count 人',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                ),
              );
            },
          ),

          // ユーザーリスト
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                var users = snapshot.data!.docs;
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nickname = (data['nickname'] ?? '').toString().toLowerCase();
                    final searchId = (data['searchId'] ?? '').toString().toLowerCase();
                    return nickname.contains(_searchQuery) || searchId.contains(_searchQuery);
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty ? '該当するユーザーがいません' : 'ユーザーがいません',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final uid = users[index].id;
                    final nickname = (data['nickname'] ?? '名前なし').toString();
                    final avatarUrl = (data['avatarUrl'] ?? '').toString();
                    final searchId = (data['searchId'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final isOfficial = data['isOfficial'] == true;
                    final isBanned = data['isBanned'] == true;
                    final createdAt = data['createdAt'] as Timestamp?;

                    return ListTile(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: uid))),
                      onLongPress: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid))),
                      leading: avatarUrl.isNotEmpty
                          ? CircleAvatar(
                              radius: 22,
                              backgroundImage: CachedNetworkImageProvider(avatarUrl),
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            )
                          : CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                nickname.isNotEmpty ? nickname[0] : '?',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(nickname,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (isOfficial) const OfficialBadge(size: 15),
                          if (isBanned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '凍結中',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        searchId.isNotEmpty ? '@$searchId' : email,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: createdAt != null
                          ? Text(
                              _formatDate(createdAt),
                              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBanOptions(BuildContext context, String uid, String nickname, bool isBanned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    nickname,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    isBanned ? Icons.lock_open : Icons.block,
                    color: isBanned ? AppTheme.success : AppTheme.error,
                  ),
                  title: Text(
                    isBanned ? '凍結を解除' : 'アカウントを凍結',
                    style: TextStyle(
                      color: isBanned ? AppTheme.success : AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmToggleBan(context, uid, nickname, isBanned);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmToggleBan(BuildContext context, String uid, String nickname, bool isBanned) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isBanned ? '凍結を解除' : 'アカウントを凍結'),
          content: Text(
            isBanned
                ? '$nickname さんの凍結を解除しますか？'
                : '$nickname さんのアカウントを凍結しますか？\n凍結されたユーザーはアプリを使用できなくなります。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _toggleBan(uid, !isBanned);
              },
              child: Text(
                isBanned ? '解除する' : '凍結する',
                style: TextStyle(
                  color: isBanned ? AppTheme.success : AppTheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleBan(String uid, bool ban) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isBanned': ban,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ban ? 'アカウントを凍結しました' : '凍結を解除しました'),
            backgroundColor: ban ? AppTheme.error : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return '${d.year}/${d.month}/${d.day}';
  }
}
