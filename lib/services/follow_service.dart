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
