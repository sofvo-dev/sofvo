import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'user_profile_screen.dart';

enum _SortType { dateDesc, dateAsc, nameAsc }

class FollowListScreen extends StatefulWidget {
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
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  String _searchQuery = '';
  _SortType _sortType = _SortType.dateDesc;
  final _searchController = TextEditingController();
  bool _isAdmin = false;

  // キャッシュ: uid -> userData
  final Map<String, Map<String, dynamic>> _userCache = {};
  List<QueryDocumentSnapshot>? _followDocs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final collection = widget.isFollowers ? 'followers' : 'following';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection(collection)
          .get();

      _followDocs = snap.docs;

      // ユーザー情報を一括取得（削除済みユーザーは除外）
      final futures = <Future>[];
      for (final doc in snap.docs) {
        final uid = doc.id;
        if (!_userCache.containsKey(uid)) {
          futures.add(
            FirebaseFirestore.instance.collection('users').doc(uid).get().then((userSnap) {
              if (!userSnap.exists) return; // 削除済みユーザーをスキップ
              final data = userSnap.data() ?? {};
              data['uid'] = uid;
              // createdAt をフォロードキュメントから取得
              final followData = doc.data();
              data['_followCreatedAt'] = followData['createdAt'];
              _userCache[uid] = data;
            }),
          );
        }
      }
      await Future.wait(futures);

      // Admin判定
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (currentUid.isNotEmpty) {
        final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
        _isAdmin = myDoc.data()?['isAdmin'] == true;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _getFilteredAndSorted() {
    if (_followDocs == null) return [];

    var users = _followDocs!
        .map((doc) => _userCache[doc.id])
        .whereType<Map<String, dynamic>>()
        .toList();

    // 検索フィルタ
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      users = users.where((u) {
        final nickname = (u['nickname'] ?? '').toString().toLowerCase();
        final area = (u['area'] ?? '').toString().toLowerCase();
        return nickname.contains(q) || area.contains(q);
      }).toList();
    }

    // ソート
    switch (_sortType) {
      case _SortType.dateDesc:
        users.sort((a, b) {
          final ta = a['_followCreatedAt'] as Timestamp?;
          final tb = b['_followCreatedAt'] as Timestamp?;
          return (tb?.millisecondsSinceEpoch ?? 0).compareTo(ta?.millisecondsSinceEpoch ?? 0);
        });
      case _SortType.dateAsc:
        users.sort((a, b) {
          final ta = a['_followCreatedAt'] as Timestamp?;
          final tb = b['_followCreatedAt'] as Timestamp?;
          return (ta?.millisecondsSinceEpoch ?? 0).compareTo(tb?.millisecondsSinceEpoch ?? 0);
        });
      case _SortType.nameAsc:
        users.sort((a, b) {
          final na = (a['nickname'] ?? '').toString().toLowerCase();
          final nb = (b['nickname'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
    }

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                // 検索バー + ソート
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: '名前・地域で検索',
                            hintStyle: TextStyle(fontSize: 14, color: AppTheme.textHint),
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_SortType>(
                        icon: Icon(Icons.sort, color: AppTheme.primaryColor),
                        onSelected: (v) => setState(() => _sortType = v),
                        itemBuilder: (_) => [
                          _buildSortItem(_SortType.dateDesc, '新しい順'),
                          _buildSortItem(_SortType.dateAsc, '古い順'),
                          _buildSortItem(_SortType.nameAsc, '名前順'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // リスト
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  PopupMenuEntry<_SortType> _buildSortItem(_SortType type, String label) {
    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          if (_sortType == type)
            const Icon(Icons.check, size: 16, color: AppTheme.primaryColor)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            fontSize: 14,
            color: _sortType == type ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: _sortType == type ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final users = _getFilteredAndSorted();

    if (_followDocs != null && _followDocs!.isEmpty) {
      return _buildEmpty();
    }

    if (users.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text('「$_searchQuery」に一致するユーザーが見つかりません',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userData = users[index];
        final uid = userData['uid'] as String;
        final nickname = userData['nickname'] ?? '名前なし';
        final avatarUrl = userData['avatarUrl'] ?? '';
        final bio = userData['bio'] ?? '';
        final area = userData['area'] ?? '';

        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: uid),
            ));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                avatarUrl.toString().isNotEmpty
                    ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl),
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1))
                    : CircleAvatar(radius: 24, backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.person_remove, size: 20, color: AppTheme.error),
                    onPressed: () => _confirmRemoveFollow(uid, nickname.toString()),
                  )
                else
                  Icon(Icons.chevron_right, color: AppTheme.textHint),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveFollow(String targetUid, String targetName) {
    final action = widget.isFollowers ? 'フォロワーから削除' : 'フォロー解除';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(action, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('「$targetName」を${action}しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeFollow(targetUid);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFollow(String targetUid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      if (widget.isFollowers) {
        // フォロワーから削除: targetUid が widget.userId をフォローしている関係を削除
        await firestore.collection('users').doc(widget.userId).collection('followers').doc(targetUid).delete();
        await firestore.collection('users').doc(targetUid).collection('following').doc(widget.userId).delete();
        await firestore.collection('users').doc(widget.userId).update({'followersCount': FieldValue.increment(-1)}).catchError((_) {});
        await firestore.collection('users').doc(targetUid).update({'followingCount': FieldValue.increment(-1)}).catchError((_) {});
      } else {
        // フォロー解除: widget.userId が targetUid をフォローしている関係を削除
        await firestore.collection('users').doc(widget.userId).collection('following').doc(targetUid).delete();
        await firestore.collection('users').doc(targetUid).collection('followers').doc(widget.userId).delete();
        await firestore.collection('users').doc(widget.userId).update({'followingCount': FieldValue.increment(-1)}).catchError((_) {});
        await firestore.collection('users').doc(targetUid).update({'followersCount': FieldValue.increment(-1)}).catchError((_) {});
      }
      _userCache.remove(targetUid);
      _followDocs = _followDocs?.where((d) => d.id != targetUid).toList();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除しました'), backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            widget.isFollowers ? 'まだフォロワーがいません' : 'まだ誰もフォローしていません',
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
