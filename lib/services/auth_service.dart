import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
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


  // Googleログイン（Web: ポップアップ優先→リダイレクトフォールバック / Android・iOS・iPadOS: signInWithProvider）
  Future<UserCredential?> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    if (kIsWeb) {
      // ポップアップを優先（リダイレクト方式はiOS Safariで ITP により失敗しやすい）
      // ポップアップがブロックされた場合のみリダイレクトにフォールバック
      try {
        return await _auth.signInWithPopup(googleProvider);
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('popup-blocked') ||
            errorStr.contains('popup-closed-by-user') ||
            errorStr.contains('cancelled-popup-request')) {
          await _auth.signInWithRedirect(googleProvider);
          return null;
        }
        rethrow;
      }
    } else {
      // Android / iOS / iPadOS: signInWithProvider を使用
      // 全ネイティブプラットフォームで統一した認証フロー
      return await _auth.signInWithProvider(googleProvider);
    }
  }

  /// セキュリティ用ランダムnonce生成
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA256ハッシュ
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Apple Credential を sign_in_with_apple パッケージで取得し Firebase OAuthCredential に変換
  /// iPad の Scene-based lifecycle で signInWithProvider が presentationAnchor を
  /// 取得できない問題を回避するため、ネイティブ認証UIを直接呼び出す
  Future<OAuthCredential> _getAppleCredentialNative() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw Exception('Apple Sign-In: identityToken が取得できませんでした');
    }

    return OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
  }

  // Appleログイン
  // Web: signInWithPopup → signInWithRedirect フォールバック
  // iOS/iPadOS: sign_in_with_apple パッケージ → signInWithCredential
  // Android: signInWithProvider（ASAuthorizationController の問題なし）
  Future<UserCredential?> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com');
      provider.addScope('email');
      provider.addScope('name');
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
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS / iPadOS: sign_in_with_apple パッケージでネイティブ認証UIを表示
      // signInWithProvider は iPad(Scene-based lifecycle)で
      // ASAuthorizationController の presentationAnchor を取得できず失敗する
      final oauthCredential = await _getAppleCredentialNative();
      return await _auth.signInWithCredential(oauthCredential);
    } else {
      // Android: signInWithProvider で問題なし
      final provider = OAuthProvider('apple.com');
      provider.addScope('email');
      provider.addScope('name');
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
    // Web: reauthenticateWithProvider は未実装のため signInWithPopup → reauthenticateWithCredential
    // Android / iOS / iPadOS: reauthenticateWithProvider（全ネイティブプラットフォーム統一）
    final provider = signInProvider;
    if (provider == 'google.com') {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        final result = await _auth.signInWithPopup(googleProvider);
        if (result.credential != null) {
          await user.reauthenticateWithCredential(result.credential!);
        }
      } else {
        final googleProvider = GoogleAuthProvider();
        await user.reauthenticateWithProvider(googleProvider);
      }
    } else if (provider == 'apple.com') {
      if (kIsWeb) {
        final appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final result = await _auth.signInWithPopup(appleProvider);
        if (result.credential != null) {
          await user.reauthenticateWithCredential(result.credential!);
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS/iPadOS: sign_in_with_apple でネイティブ認証UIを表示し再認証
        final oauthCredential = await _getAppleCredentialNative();
        await user.reauthenticateWithCredential(oauthCredential);
      } else {
        // Android: reauthenticateWithProvider で問題なし
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
    // カウント更新はCloud Functionが自動処理（サブコレクション削除がトリガー）
    final myFollowers = await userRef.collection('followers').get();
    for (final followerDoc in myFollowers.docs) {
      try {
        await firestore
            .collection('users')
            .doc(followerDoc.id)
            .collection('following')
            .doc(uid)
            .delete();
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

    // Firebase Auth サインアウト（authStateChanges が発火して画面遷移）
    // signInWithProvider を使用しているため、Firebase Auth の signOut だけで
    // OAuth セッションも含め完全にクリアされる
    await _auth.signOut();
  }
}
