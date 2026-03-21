import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // シングルトンパターン: アプリ更新時にセッションが切れないようにする
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザー
  User? get currentUser => _auth.currentUser;

  // 認証状態の変化を監視（idTokenChangesはWeb Safariでもログイン後に確実に発火する）
  Stream<User?> get authStateChanges => _auth.idTokenChanges();

  // メール＆パスワードでログイン
  Future<UserCredential> signInWithEmail(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // メール＆パスワードで新規登録
  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result;
  }


  // Googleログイン（Web: ポップアップ優先→リダイレクトフォールバック / Android: signInWithProvider / iOS: GoogleSignIn）
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      // ポップアップを優先（リダイレクト方式はiOS Safariで ITP により失敗しやすい）
      // ポップアップがブロックされた場合のみリダイレクトにフォールバック
      try {
        return await _auth.signInWithPopup(googleProvider);
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('popup-blocked') ||
            errorStr.contains('popup-closed-by-user') ||
            errorStr.contains('cancelled-popup-request')) {
          // ポップアップがブロックされた場合はリダイレクト方式にフォールバック
          await _auth.signInWithRedirect(googleProvider);
          return null;
        }
        rethrow;
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // AndroidではsignInWithProviderを使用（Chrome Custom Tabベース）
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      return await _auth.signInWithProvider(googleProvider);
    } else {
      // iOS: ネイティブGoogleSignIn SDK
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) return null; // ユーザーがキャンセル

      final authentication = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      return await _auth.signInWithCredential(credential);
    }
  }

  // Appleログイン（Web: ポップアップ優先→リダイレクトフォールバック / iOS・iPadOS・Android: signInWithProvider）
  Future<UserCredential?> signInWithApple() async {
    final provider = OAuthProvider('apple.com');
    provider.addScope('email');
    provider.addScope('name');

    if (kIsWeb) {
      // ポップアップを優先（リダイレクト方式はiOS Safariで ITP により失敗しやすい）
      try {
        return await _auth.signInWithPopup(provider);
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('popup-blocked') ||
            errorStr.contains('popup-closed-by-user') ||
            errorStr.contains('cancelled-popup-request')) {
          await _auth.signInWithRedirect(provider);
          return null;
        }
        rethrow;
      }
    } else {
      // iOS / iPadOS / Android: Firebase の signInWithProvider を使用
      // Firebase SDK が ASAuthorizationController の presentationContextProvider を
      // 内部で適切に処理するため、iPad（Scene-based lifecycle）でも安定動作する
      // 注: sign_in_with_apple パッケージは presentationContextProvider を設定しないため
      //     iPad で認証ダイアログが表示されずエラーになる問題があった
      return await _auth.signInWithProvider(provider);
    }
  }

  // パスワード変更（再認証 → 更新）
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('ユーザーが見つかりません');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// ログインプロバイダを返す ('password', 'google.com', 'apple.com')
  String get signInProvider {
    final user = _auth.currentUser;
    if (user == null) return 'password';
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') return 'google.com';
      if (info.providerId == 'apple.com') return 'apple.com';
    }
    return 'password';
  }

  // アカウント削除（再認証 → Firestoreデータ全削除 → Auth削除）
  // password: メール認証の場合のみ必要。Google/Appleの場合はnullでOK。
  Future<void> deleteAccount([String? password]) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('ユーザーが見つかりません');
    }

    // プロバイダに応じた再認証
    final provider = signInProvider;
    if (provider == 'google.com') {
      if (kIsWeb) {
        // Web: signInWithPopupでクレデンシャルを取得→再認証
        final googleProvider = GoogleAuthProvider();
        final result = await _auth.signInWithPopup(googleProvider);
        if (result.credential != null) {
          await user.reauthenticateWithCredential(result.credential!);
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final googleProvider = GoogleAuthProvider();
        await user.reauthenticateWithProvider(googleProvider);
      } else {
        // iOS: ネイティブ GoogleSignIn
        final googleSignIn = GoogleSignIn();
        final account = await googleSignIn.signIn();
        if (account == null) throw Exception('Google認証がキャンセルされました');
        final authentication = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: authentication.accessToken,
          idToken: authentication.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } else if (provider == 'apple.com') {
      if (kIsWeb) {
        // Web: reauthenticateWithProvider は未実装のため、signInWithPopup で再認証
        final appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final result = await _auth.signInWithPopup(appleProvider);
        if (result.credential != null) {
          await user.reauthenticateWithCredential(result.credential!);
        }
      } else {
        // iOS / iPadOS: reauthenticateWithProvider を使用
        // Firebase SDK が presentationContextProvider を適切に処理するため iPad でも安定動作
        final appleProvider = OAuthProvider('apple.com');
        await user.reauthenticateWithProvider(appleProvider);
      }
    } else {
      // メール/パスワード認証
      if (password == null || password.isEmpty || user.email == null) {
        throw Exception('パスワードを入力してください');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }

    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    // ── サブコレクションの削除 ──
    final subcollections = [
      'following', 'followers', 'notifications', 'bookmarks',
      'blockedUsers', 'gadgets', 'gadgetCategories', 'pointHistory',
      'hiddenPosts', 'private',
    ];
    for (final sub in subcollections) {
      final docs = await userRef.collection(sub).get();
      if (docs.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in docs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // ── 他ユーザーのフォロー/フォロワーから自分を削除 ──
    // 自分をフォローしているユーザーのfollowingから削除
    final myFollowers = await userRef.collection('followers').get();
    for (final followerDoc in myFollowers.docs) {
      try {
        await firestore
            .collection('users')
            .doc(followerDoc.id)
            .collection('following')
            .doc(uid)
            .delete();
        await firestore.collection('users').doc(followerDoc.id).update({
          'followingCount': FieldValue.increment(-1),
        });
      } catch (_) {}
    }
    // 自分がフォローしているユーザーのfollowersから削除
    final myFollowing = await userRef.collection('following').get();
    for (final followingDoc in myFollowing.docs) {
      try {
        await firestore
            .collection('users')
            .doc(followingDoc.id)
            .collection('followers')
            .doc(uid)
            .delete();
        await firestore.collection('users').doc(followingDoc.id).update({
          'followersCount': FieldValue.increment(-1),
        });
      } catch (_) {}
    }

    // ── 投稿を削除 ──
    final posts = await firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get();
    for (final postDoc in posts.docs) {
      // 投稿のサブコレクション（likes, comments）も削除
      for (final postSub in ['likes', 'comments']) {
        final subDocs = await postDoc.reference.collection(postSub).get();
        if (subDocs.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in subDocs.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
      await postDoc.reference.delete();
    }

    // ── 自分のコメントを他の投稿から削除 ──
    try {
      final myComments = await firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: uid)
          .get();
      for (final commentDoc in myComments.docs) {
        try {
          await commentDoc.reference.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('コメント削除スキップ（インデックス未作成の可能性）: $e');
    }

    // ── 自分のいいねを他の投稿から削除 ──
    try {
      final myLikes = await firestore
          .collectionGroup('likes')
          .where(FieldPath.documentId, isEqualTo: uid)
          .get();
      for (final likeDoc in myLikes.docs) {
        try {
          await likeDoc.reference.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('いいね削除スキップ（インデックス未作成の可能性）: $e');
    }

    // ── ユーザードキュメントを削除 ──
    await userRef.delete();

    // ── Firebase Authアカウントを削除 ──
    await user.delete();
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ログアウト（OAuth セッション・キャッシュ・FCMトークンも完全にクリア）
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;

    // FCMトークンをFirestoreから削除（ログアウト後にプッシュ通知が届かないように）
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('private').doc('info')
            .set({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('signOut: FCMトークン削除失敗: $e');
      }
    }

    // Google OAuthセッションをクリア（アカウント切り替えを可能にする）
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('signOut: Google Sign-Out失敗: $e');
    }

    // Firebase Auth サインアウト（authStateChanges が発火して画面遷移）
    await _auth.signOut();
  }
}
