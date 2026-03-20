import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  /// セキュアなランダムnonce文字列を生成
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// nonceのSHA256ハッシュを返す
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Appleログイン（Web: ポップアップ優先→リダイレクトフォールバック / iOS・iPadOS: ネイティブ sign_in_with_apple）
  Future<UserCredential?> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com');
      provider.addScope('email');
      provider.addScope('name');
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
      // iOS / iPadOS: sign_in_with_apple パッケージでネイティブ認証フローを使用
      // signInWithProvider は iPad で不安定なため、ネイティブ SDK を直接利用する
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(oauthCredential);
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

  // アカウント削除（再認証 → Firestoreデータ全削除 → Auth削除）
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('ユーザーが見つかりません');
    }

    // 再認証
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

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
    final myComments = await firestore
        .collectionGroup('comments')
        .where('userId', isEqualTo: uid)
        .get();
    for (final commentDoc in myComments.docs) {
      try {
        await commentDoc.reference.delete();
      } catch (_) {}
    }

    // ── 自分のいいねを他の投稿から削除 ──
    final myLikes = await firestore
        .collectionGroup('likes')
        .where(FieldPath.documentId, isEqualTo: uid)
        .get();
    for (final likeDoc in myLikes.docs) {
      try {
        await likeDoc.reference.delete();
      } catch (_) {}
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

    // Firestoreローカルキャッシュをクリア（前ユーザーのデータ残留を防止）
    // Firebase Auth signOut の前に実行（認証コンテキストがある状態でクリアする）
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      debugPrint('signOut: Firestoreキャッシュクリア失敗: $e');
    }

    // Firebase Auth サインアウト（最後に実行 → authStateChanges が発火して画面遷移）
    await _auth.signOut();
  }
}
