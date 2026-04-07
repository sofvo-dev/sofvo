import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';
import '../../widgets/official_badge.dart';
import '../../services/follow_service.dart';
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

  final Set<String> _togglingIds = {};
  String _mySearchId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMySearchId();
    FollowService.instance.addListener(_onFollowChanged);
  }

  void _onFollowChanged() {
    if (mounted) setState(() {});
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
    FollowService.instance.removeListener(_onFollowChanged);
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
    if (_currentUser == null || _togglingIds.contains(targetUid)) return;
    final myUid = _currentUser!.uid;
    final wasFollowing = FollowService.instance.isFollowing(targetUid);

    setState(() => _togglingIds.add(targetUid));

    try {
      // 通知用に自分の情報を先に取得
      String myNickname = '不明';
      String myAvatarUrl = '';
      if (!wasFollowing) {
        final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
        final myData = myDoc.data() ?? {};
        myNickname = (myData['nickname'] as String?) ?? '不明';
        myAvatarUrl = (myData['avatarUrl'] as String?) ?? '';
      }

      await FollowService.instance.toggleFollow(
        targetUid: targetUid,
        targetNickname: targetName,
      );
      // UI は FollowService のリスナー (_onFollowChanged) が自動更新

      if (!wasFollowing) {
        NotificationService.sendFollowNotification(
          targetUserId: targetUid,
          senderId: myUid,
          senderName: myNickname,
          senderAvatar: myAvatarUrl,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(wasFollowing
                ? '$targetNameさんのフォローを解除しました'
                : '$targetNameさんをフォローしました！'),
            backgroundColor: wasFollowing ? AppTheme.warning : AppTheme.success));
      }
    } catch (e) {
      debugPrint('フォロー切替エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フォロー操作に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(targetUid));
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
    final qrData = _mySearchId.isNotEmpty ? 'sofvo://friend/$_mySearchId' : '';

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
                if (qrData.isNotEmpty)
                  Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text('@$_mySearchId',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    ],
                  )
                else
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 48, color: AppTheme.textHint),
                        SizedBox(height: 8),
                        Text('IDが未設定です', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                        Text('プロフィールでIDを設定してください', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openFriendScanner,
            icon: const Icon(Icons.qr_code_scanner, size: 22),
            label: const Text('QRコードを読み取る', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openFriendScanner() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カメラ機能はネイティブアプリで利用できます'), backgroundColor: AppTheme.info),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FriendQRScannerPage(
          onScanned: (code) async {
            Navigator.pop(context);
            await _handleFriendQR(code);
          },
        ),
      ),
    );
  }

  Future<void> _handleFriendQR(String code) async {
    // フォーマット: sofvo://friend/{searchId}
    if (!code.startsWith('sofvo://friend/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('友達追加用のQRコードではありません'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    final searchId = code.replaceFirst('sofvo://friend/', '').trim();
    if (searchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QRコードの形式が正しくありません'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    // 自分自身チェック
    if (searchId == _mySearchId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自分のQRコードです'), backgroundColor: AppTheme.info),
        );
      }
      return;
    }

    // ユーザー検索
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('searchId', isEqualTo: searchId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザーが見つかりませんでした'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    final userId = snap.docs.first.id;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
      );
    }
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
    final isFollowing = FollowService.instance.isFollowing(uid);

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
                    if (user['isOfficial'] == true)
                      const OfficialBadge(size: 16),
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

// ━━━ 友達QRスキャナーページ ━━━
class _FriendQRScannerPage extends StatefulWidget {
  final Function(String) onScanned;
  const _FriendQRScannerPage({required this.onScanned});

  @override
  State<_FriendQRScannerPage> createState() => _FriendQRScannerPageState();
}

class _FriendQRScannerPageState extends State<_FriendQRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('友達のQRコードをスキャン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                setState(() => _hasScanned = true);
                widget.onScanned(barcode!.rawValue!);
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: const Text(
              '相手のQRコードを枠内に合わせてください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
