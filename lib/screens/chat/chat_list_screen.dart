import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;

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

  void _openChat({
    required String chatId,
    required String title,
    required String type,
    String? otherUserId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          chatTitle: title,
          chatType: type,
          otherUserId: otherUserId,
        ),
      ),
    );
  }

  // ── DM作成 or 既存DM取得 ──
  Future<void> _startDmWith(String otherUid, String otherName) async {
    if (_currentUser == null) return;
    final myUid = _currentUser!.uid;

    final existing = await FirebaseFirestore.instance
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
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();
      final myName = (myDoc.data()?['nickname'] as String?) ?? '自分';

      final ref =
          await FirebaseFirestore.instance.collection('chats').add({
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
      _openChat(
        chatId: chatId,
        title: otherName,
        type: 'dm',
        otherUserId: otherUid,
      );
    }
  }

  // ── 新規DMシート ──
  void _showNewDmSheet() {
    if (_currentUser == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('新しいメッセージ',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .collection('following')
                        .snapshots(),
                    builder: (context, followSnap) {
                      if (followSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final followDocs = followSnap.data?.docs ?? [];
                      if (followDocs.isEmpty) {
                        return const Center(
                          child: Text('フォロー中のユーザーがいません',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: followDocs.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: Colors.grey[100]),
                        itemBuilder: (_, i) {
                          final followData = followDocs[i].data()
                              as Map<String, dynamic>?;
                          final uid = followDocs[i].id;
                          final name =
                              (followData?['nickname'] as String?) ??
                                  'ユーザー';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                              child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _startDmWith(uid, name);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  const Text('チャット',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showNewDmSheet,
                    child: const Icon(Icons.edit_square, size: 24, color: AppTheme.textPrimary),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
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
                  Tab(text: '個別チャット'),
                  Tab(text: 'グループチャット'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab('dm'),
                _buildGroupChatTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // グループチャット（チーム + 大会を統合）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildGroupChatTab() {
    if (_currentUser == null) {
      return const Center(child: Text('ログインしてください'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('type', whereIn: ['team', 'tournament'])
          .where('members', arrayContains: _currentUser!.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (snapshot.hasError) {
          return _buildEmptyState('group');
        }

        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return _buildEmptyState('group');
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          itemCount: chats.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, thickness: 1, color: Colors.grey[100], indent: 80),
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            final type = (data['type'] as String?) ?? 'team';
            return _buildFirestoreChatTile(chatId, data, type);
          },
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Firestoreからチャット一覧を取得
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildChatTab(String type) {
    if (_currentUser == null) {
      return const Center(child: Text('ログインしてください'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('type', isEqualTo: type)
          .where('members', arrayContains: _currentUser!.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (snapshot.hasError) {
          return _buildEmptyState(type);
        }

        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return _buildEmptyState(type);
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          itemCount: chats.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, thickness: 1, color: Colors.grey[100], indent: 80),
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            return _buildFirestoreChatTile(chatId, data, type);
          },
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 未読判定
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  bool _hasUnread(Map<String, dynamic> data) {
    if (_currentUser == null) return false;
    final lastReadMap = data['lastRead'] as Map<String, dynamic>? ?? {};
    final myLastRead = lastReadMap[_currentUser!.uid] as Timestamp?;
    final lastMessageAt = data['lastMessageAt'] as Timestamp?;
    if (lastMessageAt == null) return false;
    if (myLastRead == null) return true;
    return lastMessageAt.toDate().isAfter(myLastRead.toDate());
  }

  Widget _buildFirestoreChatTile(
      String chatId, Map<String, dynamic> data, String type) {
    final memberNames =
        data['memberNames'] as Map<String, dynamic>? ?? {};
    final lastMessage = (data['lastMessage'] as String?) ?? '';
    final lastAt = data['lastMessageAt'] as Timestamp?;
    final timeText = _formatTime(lastAt);
    final unread = _hasUnread(data);

    String title;
    if (type == 'dm') {
      final otherEntry = memberNames.entries.firstWhere(
        (e) => e.key != _currentUser!.uid,
        orElse: () => MapEntry('', 'ユーザー'),
      );
      title = otherEntry.value as String;
    } else {
      title = (data['name'] as String?) ?? 'チャット';
    }

    final initial = title.isNotEmpty ? title[0] : '?';

    IconData icon;
    Color iconColor;
    if (type == 'team') {
      icon = Icons.groups;
      iconColor = AppTheme.success;
    } else if (type == 'tournament') {
      icon = Icons.emoji_events;
      iconColor = AppTheme.accentColor;
    } else {
      icon = Icons.person;
      iconColor = AppTheme.primaryColor;
    }

    return Container(
      color: unread
          ? AppTheme.primaryColor.withValues(alpha: 0.02)
          : Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: type == 'dm'
            ? CircleAvatar(
                radius: 24,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(initial,
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              )
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            lastMessage.isEmpty ? 'メッセージはありません' : lastMessage,
            style: TextStyle(
                fontSize: 13,
                color: unread ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: unread ? FontWeight.w500 : FontWeight.normal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeText,
                style: TextStyle(
                    fontSize: 12,
                    color: unread
                        ? AppTheme.primaryColor
                        : AppTheme.textHint)),
            if (unread) ...[
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          String? otherUserId;
          if (type == 'dm') {
            final members =
                List<String>.from(data['members'] ?? []);
            otherUserId = members.firstWhere(
              (m) => m != _currentUser!.uid,
              orElse: () => '',
            );
          }
          _openChat(
            chatId: chatId,
            title: title,
            type: type,
            otherUserId: otherUserId,
          );
        },
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 空状態表示
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildEmptyState(String type) {
    IconData icon;
    String message;
    String actionLabel;
    VoidCallback? onAction;

    if (type == 'dm') {
      icon = Icons.chat_bubble_outline;
      message = 'まだDMはありません';
      actionLabel = '新しいメッセージを送る';
      onAction = _showNewDmSheet;
    } else if (type == 'group') {
      icon = Icons.groups_outlined;
      message = 'グループチャットはありません\nチームや大会に参加するとここに表示されます';
      actionLabel = '';
      onAction = null;
    } else if (type == 'team') {
      icon = Icons.groups_outlined;
      message = 'チームチャットはありません\nチーム管理画面からチャットを開始できます';
      actionLabel = '';
      onAction = null;
    } else {
      icon = Icons.emoji_events_outlined;
      message = '大会チャットはありません\n大会詳細画面からチャットを開始できます';
      actionLabel = '';
      onAction = null;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.edit, size: 18),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    if (diff.inDays < 2) return '昨日';
    return '${date.month}/${date.day}';
  }
}
