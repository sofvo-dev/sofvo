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

  // ── サンプルチャットをFirestoreに作成して開く ──
  Future<void> _openOrCreateSampleChat({
    required String name,
    required String type,
  }) async {
    if (_currentUser == null) return;

    // 既存チャットを探す
    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('type', isEqualTo: type)
        .where('name', isEqualTo: name)
        .where('members', arrayContains: _currentUser!.uid)
        .get();

    String chatId;
    if (existing.docs.isNotEmpty) {
      chatId = existing.docs.first.id;
    } else {
      // 作成
      final ref =
          await FirebaseFirestore.instance.collection('chats').add({
        'type': type,
        'name': name,
        'members': [_currentUser!.uid],
        'memberNames': {_currentUser!.uid: '自分'},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = ref.id;
    }

    if (mounted) {
      _openChat(chatId: chatId, title: name, type: type);
    }
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

  // ── サンプルDMを作成して開く ──
  Future<void> _openOrCreateSampleDm(String name) async {
    if (_currentUser == null) return;

    // 既存DMを探す（nameフィールドで検索）
    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('name', isEqualTo: 'dm_$name')
        .where('members', arrayContains: _currentUser!.uid)
        .get();

    String chatId;
    if (existing.docs.isNotEmpty) {
      chatId = existing.docs.first.id;
    } else {
      final ref =
          await FirebaseFirestore.instance.collection('chats').add({
        'type': 'dm',
        'name': 'dm_$name',
        'members': [_currentUser!.uid, 'sample_$name'],
        'memberNames': {
          _currentUser!.uid: '自分',
          'sample_$name': name,
        },
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      chatId = ref.id;
    }

    if (mounted) {
      _openChat(
        chatId: chatId,
        title: name,
        type: 'dm',
        otherUserId: 'sample_$name',
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
          // ━━━ X-style ヘッダー ━━━
          Container(
            color: Colors.white,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  const SizedBox(width: 26),
                  const Spacer(),
                  const Text('チャット',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showNewDmSheet,
                    child: const Icon(Icons.edit_square,
                        size: 24, color: AppTheme.textPrimary),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.normal),
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
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
  // グループチャット（チーム + 大会）
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
          return _buildCombinedSampleList();
        }

        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return _buildCombinedSampleList();
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          itemCount: chats.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, thickness: 1, color: Colors.grey[100], indent: 80),
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final chatId = chats[index].id;
            final type = data['type'] as String? ?? 'team';
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
          return _buildSampleList(type);
        }

        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return _buildSampleList(type);
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

  Widget _buildFirestoreChatTile(
      String chatId, Map<String, dynamic> data, String type) {
    final memberNames =
        data['memberNames'] as Map<String, dynamic>? ?? {};
    final lastMessage = (data['lastMessage'] as String?) ?? '';
    final lastAt = data['lastMessageAt'] as Timestamp?;
    final timeText = _formatTime(lastAt);

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
      color: Colors.white,
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
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            lastMessage.isEmpty ? 'メッセージはありません' : lastMessage,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text(timeText,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textHint)),
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
  // サンプル表示（タップで開ける）
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSampleList(String type) {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        _buildSampleDmTile(
          name: 'たけし',
          message: '明日の件了解です！会場で会いましょう',
          time: '11:30',
          unread: 1,
          onTap: () => _openOrCreateSampleDm('たけし'),
        ),
        _buildSampleDivider(),
        _buildSampleDmTile(
          name: 'はなこ',
          message: 'メンバー募集の件、ありがとうございます！',
          time: '昨日',
          unread: 0,
          onTap: () => _openOrCreateSampleDm('はなこ'),
        ),
        _buildSampleDivider(),
        _buildSampleDmTile(
          name: 'けんじ',
          message: '大会お疲れ様でした！',
          time: '2/11',
          unread: 0,
          onTap: () => _openOrCreateSampleDm('けんじ'),
        ),
        _buildSampleDivider(),
        _buildSampleDmTile(
          name: 'さとし',
          message: '練習参加の件、了解しました',
          time: '2/10',
          unread: 0,
          onTap: () => _openOrCreateSampleDm('さとし'),
        ),
      ],
    );
  }

  Widget _buildCombinedSampleList() {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        _buildSampleTile(
          icon: Icons.groups,
          iconBgColor: AppTheme.success,
          title: 'チーム・サンダース',
          subtitle: 'けんじ: 次の練習は土曜10時からです',
          time: '9:45',
          unread: 3,
          onTap: () => _openOrCreateSampleChat(
              name: 'チーム・サンダース', type: 'team'),
        ),
        _buildSampleDivider(),
        _buildSampleTile(
          icon: Icons.emoji_events,
          iconBgColor: AppTheme.accentColor,
          title: '第5回 世田谷カップ',
          subtitle: 'たけし: 明日の集合時間は8:30です！',
          time: '10:23',
          unread: 5,
          onTap: () => _openOrCreateSampleChat(
              name: '第5回 世田谷カップ', type: 'tournament'),
        ),
        _buildSampleDivider(),
        _buildSampleTile(
          icon: Icons.groups,
          iconBgColor: AppTheme.info,
          title: 'チーム・フェニックス',
          subtitle: 'ゆみ: 来週の大会の打ち合わせしませんか？',
          time: '昨日',
          unread: 0,
          onTap: () => _openOrCreateSampleChat(
              name: 'チーム・フェニックス', type: 'team'),
        ),
        _buildSampleDivider(),
        _buildSampleTile(
          icon: Icons.emoji_events,
          iconBgColor: AppTheme.primaryColor,
          title: '春のソフトバレー大会',
          subtitle: '主催者: エントリーありがとうございます',
          time: '昨日',
          unread: 0,
          onTap: () => _openOrCreateSampleChat(
              name: '春のソフトバレー大会', type: 'tournament'),
        ),
      ],
    );
  }

  Widget _buildSampleTile({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String time,
    required int unread,
    required VoidCallback onTap,
  }) {
    return Container(
      color: unread > 0
          ? AppTheme.primaryColor.withValues(alpha: 0.02)
          : Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBgColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconBgColor, size: 24),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight:
                    unread > 0 ? FontWeight.bold : FontWeight.w500,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: TextStyle(
                    fontSize: 12,
                    color: unread > 0
                        ? AppTheme.primaryColor
                        : AppTheme.textHint)),
            if (unread > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$unread',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSampleDmTile({
    required String name,
    required String message,
    required String time,
    required int unread,
    required VoidCallback onTap,
  }) {
    return Container(
      color: unread > 0
          ? AppTheme.primaryColor.withValues(alpha: 0.02)
          : Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              AppTheme.primaryColor.withValues(alpha: 0.12),
          child: Text(name[0],
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ),
        title: Text(name,
            style: TextStyle(
                fontSize: 15,
                fontWeight:
                    unread > 0 ? FontWeight.bold : FontWeight.w500,
                color: AppTheme.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(message,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: TextStyle(
                    fontSize: 12,
                    color: unread > 0
                        ? AppTheme.primaryColor
                        : AppTheme.textHint)),
            if (unread > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$unread',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSampleDivider() {
    return Divider(
        height: 1, thickness: 1, color: Colors.grey[100], indent: 80);
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
