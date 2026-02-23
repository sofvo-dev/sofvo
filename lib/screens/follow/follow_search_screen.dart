import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../services/notification_service.dart';
import '../profile/user_profile_screen.dart';

class FollowSearchScreen extends StatefulWidget {
  const FollowSearchScreen({super.key});

  @override
  State<FollowSearchScreen> createState() => _FollowSearchScreenState();
}

class _FollowSearchScreenState extends State<FollowSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currentUser = FirebaseAuth.instance.currentUser;

  // ID・ニックネーム検索
  final _idController = TextEditingController();
  bool _idSearching = false;
  List<Map<String, dynamic>> _idResults = [];

  // フォロー状態キャッシュ
  final Set<String> _followingIds = {};
  String _mySearchId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFollowing();
    _loadMySearchId();
  }

  Future<void> _loadFollowing() async {
    if (_currentUser == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('following')
        .get();
    setState(() {
      _followingIds.addAll(snap.docs.map((d) => d.id));
    });
  }

  Future<void> _loadMySearchId() async {
    if (_currentUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _mySearchId = (doc.data()?['searchId'] as String?) ?? '';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _idController.dispose();
    super.dispose();
  }

  // ── ID・ニックネーム検索 ──
  Future<void> _searchById() async {
    final query = _idController.text.trim().replaceAll('@', '');
    if (query.isEmpty) return;
    setState(() => _idSearching = true);

    try {
      // まず searchId の完全一致を試す
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('searchId', isEqualTo: query)
          .limit(5)
          .get();

      List<Map<String, dynamic>> results = [];
      final addedUids = <String>{};
      for (final doc in snap.docs) {
        if (doc.id == _currentUser?.uid) continue;
        final data = doc.data();
        data['uid'] = doc.id;
        results.add(data);
        addedUids.add(doc.id);
      }

      // 完全一致がない場合、ID・ニックネーム・エリアで部分一致検索
      if (results.isEmpty) {
        final allSnap = await FirebaseFirestore.instance
            .collection('users')
            .limit(100)
            .get();
        final lowerQuery = query.toLowerCase();
        for (final doc in allSnap.docs) {
          if (doc.id == _currentUser?.uid) continue;
          if (addedUids.contains(doc.id)) continue;
          final data = doc.data();
          final sid = (data['searchId'] ?? '').toString().toLowerCase();
          final nick = (data['nickname'] ?? '').toString().toLowerCase();
          if (sid.contains(lowerQuery) ||
              nick.contains(lowerQuery)) {
            data['uid'] = doc.id;
            results.add(data);
          }
        }
      }

      setState(() {
        _idResults = results;
        _idSearching = false;
      });
    } catch (e) {
      setState(() => _idSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('検索エラー: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  // ── フォロー切替 ──
  Future<void> _toggleFollow(String targetUid, String targetName) async {
    if (_currentUser == null) return;
    final myUid = _currentUser!.uid;
    final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    final targetRef = FirebaseFirestore.instance.collection('users').doc(targetUid);

    if (_followingIds.contains(targetUid)) {
      // フォロー解除
      await myRef.collection('following').doc(targetUid).delete();
      await targetRef.collection('followers').doc(myUid).delete();
      await myRef.update({'followingCount': FieldValue.increment(-1)});
      await targetRef.update({'followersCount': FieldValue.increment(-1)});

      setState(() => _followingIds.remove(targetUid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$targetNameさんのフォローを解除しました'),
            backgroundColor: AppTheme.textSecondary));
      }
    } else {
      // フォロー
      await myRef.collection('following').doc(targetUid).set({
        'nickname': targetName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await targetRef.collection('followers').doc(myUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
      await myRef.update({'followingCount': FieldValue.increment(1)});
      await targetRef.update({'followersCount': FieldValue.increment(1)});

      // フォロー通知
      final myDoc = await myRef.get();
      final myData = myDoc.data() ?? {};
      NotificationService.sendFollowNotification(
        targetUserId: targetUid,
        senderId: myUid,
        senderName: myData['nickname'] ?? '不明',
        senderAvatar: myData['avatarUrl'] ?? '',
      );

      setState(() => _followingIds.add(targetUid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$targetNameさんをフォローしました！'),
            backgroundColor: AppTheme.success));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('友達をさがす'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'ID・ニックネーム検索'),
            Tab(text: 'QRコード'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIdSearchTab(),
          _buildQrCodeTab(),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  // ID検索タブ
  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildIdSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '相手のIDまたはニックネームで検索できます。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _idController,
            builder: (context, value, child) {
              return TextField(
                controller: _idController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: '例: @nakamura123 またはニックネーム',
                  hintStyle: const TextStyle(fontSize: 15, color: AppTheme.textHint),
                  prefixIcon: const Icon(Icons.alternate_email, size: 22),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _idController.clear();
                            setState(() => _idResults = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
                onSubmitted: (_) => _searchById(),
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _idController,
            builder: (context, value, child) {
              return ElevatedButton(
                onPressed: value.text.isNotEmpty ? _searchById : null,
                style: ElevatedButton.styleFrom(disabledBackgroundColor: Colors.grey[300]),
                child: _idSearching
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('検索する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
            },
          ),
          if (_idResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${_idResults.length}件見つかりました',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ..._idResults.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildUserCard(u),
                )),
          ] else if (!_idSearching && _idController.text.isNotEmpty && _idResults.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  const Text('ユーザーが見つかりませんでした',
                      style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  // QRコードタブ
  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildQrCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                const Text('マイQRコード',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('相手にこのQRコードを読み取ってもらいましょう',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha:0.2), width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 120, color: AppTheme.primaryColor),
                      const SizedBox(height: 8),
                      Text(_mySearchId.isNotEmpty ? '@$_mySearchId' : '未設定',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('カメラ機能はネイティブアプリで利用できます'), backgroundColor: AppTheme.info));
            },
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            label: const Text('QRコードを読み取る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  // ユーザーカード
  // ━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildUserCard(Map<String, dynamic> user) {
    final uid = user['uid'] ?? '';
    final nickname = (user['nickname'] ?? '名無し').toString();
    final searchId = (user['searchId'] ?? '').toString();
    final experience = (user['experience'] ?? '').toString();
    final avatarUrl = (user['avatarUrl'] ?? '').toString();
    final area = user['area'] is String
        ? user['area']
        : user['area'] is Map
            ? '${(user['area'] as Map)['prefecture'] ?? ''}'
            : '';
    final bio = (user['bio'] ?? '').toString();
    final isFollowing = _followingIds.contains(uid);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid)),
        );
      },
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          avatarUrl.isNotEmpty
              ? CircleAvatar(radius: 26, backgroundImage: NetworkImage(avatarUrl),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha:0.12))
              : CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha:0.12),
                  child: Text(nickname.isNotEmpty ? nickname[0] : '?',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(nickname,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (experience.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(experience,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentColor)),
                      ),
                    ],
                  ],
                ),
                if (searchId.isNotEmpty)
                  Text('@$searchId', style: const TextStyle(fontSize: 13, color: AppTheme.textHint)),
                if (area.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.location_on, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 2),
                    Flexible(child: Text(area,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                if (bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(bio, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isFollowing
              ? OutlinedButton(
                  onPressed: () => _toggleFollow(uid, nickname),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: Colors.grey[300]!),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('フォロー中', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )
              : ElevatedButton(
                  onPressed: () => _toggleFollow(uid, nickname),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  child: const Text('フォロー', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
    ),
    );
  }
}
