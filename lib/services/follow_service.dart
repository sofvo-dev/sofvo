import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// フォロー状態を一元管理するサービス
/// - 自分の following サブコレクションをリアルタイム監視
/// - 全画面で同じフォロー状態を共有
/// - フォロー/フォロー解除の操作もここで一元処理
class FollowService extends ChangeNotifier {
  static final FollowService _instance = FollowService._();
  static FollowService get instance => _instance;
  FollowService._();

  final _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _followingSub;
  String _currentUid = '';

  /// 自分がフォロー中のUID一覧（リアルタイム更新）
  final Set<String> _followingIds = {};
  Set<String> get followingIds => Set.unmodifiable(_followingIds);

  /// 監視開始（ログイン後に1回呼ぶ）
  void startListening(String uid) {
    if (uid == _currentUid && _followingSub != null) return;
    stopListening();
    _currentUid = uid;
    if (uid.isEmpty) return;

    _followingSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      _followingIds.clear();
      for (final doc in snapshot.docs) {
        _followingIds.add(doc.id);
      }
      notifyListeners();
    });
  }

  /// 監視停止（ログアウト時に呼ぶ）
  void stopListening() {
    _followingSub?.cancel();
    _followingSub = null;
    _followingIds.clear();
    _currentUid = '';
  }

  /// フォロー中かどうか
  bool isFollowing(String targetUid) => _followingIds.contains(targetUid);

  /// フォロー/フォロー解除
  Future<void> toggleFollow({
    required String targetUid,
    String? targetNickname,
    String? myNickname,
  }) async {
    final uid = _currentUid;
    if (uid.isEmpty || targetUid == uid) return;

    final wasFollowing = _followingIds.contains(targetUid);
    final myRef = _firestore.collection('users').doc(uid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    if (wasFollowing) {
      await myRef.collection('following').doc(targetUid).delete();
      await targetRef.collection('followers').doc(uid).delete().catchError((_) {});
    } else {
      await myRef.collection('following').doc(targetUid).set({
        'nickname': targetNickname ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await targetRef.collection('followers').doc(uid).set({
        'nickname': myNickname ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    // snapshots() リスナーが自動で _followingIds を更新 → notifyListeners()
  }

  /// 公式アカウント（isOfficial==true）を自動フォローする。
  /// 登録時・起動時に呼ぶ。`officialAutoFollowed` フラグで「一度だけ」に限定し、
  /// ユーザーが後から公式を自分でフォロー解除した場合に再フォローしないようにする。
  /// 相手（公式）を一方向にフォローするだけ（公式が全員をフォローし返すことはない）。
  Future<void> ensureOfficialFollow({required String myUid, String? myNickname}) async {
    if (myUid.isEmpty) return;
    try {
      final meRef = _firestore.collection('users').doc(myUid);
      final meDoc = await meRef.get();
      if (meDoc.data()?['officialAutoFollowed'] == true) return; // 実行済み

      final officials =
          await _firestore.collection('users').where('isOfficial', isEqualTo: true).get();
      // 公式アカウントが1件も取れなかった場合はフラグを立てない。
      // 立ててしまうと二度と再試行せず、そのユーザーは永久に未フォローになる。
      if (officials.docs.isEmpty) return;
      for (final doc in officials.docs) {
        final officialUid = doc.id;
        if (officialUid == myUid) continue;
        final already = await meRef.collection('following').doc(officialUid).get();
        if (already.exists) continue;
        final officialName = (doc.data()['nickname'] ?? '').toString();
        await meRef.collection('following').doc(officialUid).set({
          'nickname': officialName,
          'avatarUrl': (doc.data()['avatarUrl'] ?? '').toString(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('users')
            .doc(officialUid)
            .collection('followers')
            .doc(myUid)
            .set({
          'nickname': myNickname ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
      await meRef.update({'officialAutoFollowed': true}).catchError((_) {});
    } catch (e) {
      debugPrint('公式アカウントの自動フォローに失敗: $e');
    }
  }

  /// 特定ユーザーのフォロー/フォロワー数をリアルタイムで取得するストリーム
  Stream<int> followingCountStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> followersCountStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
