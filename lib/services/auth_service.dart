import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザー
  User? get currentUser => _auth.currentUser;

  // 認証状態の変化を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Googleログイン（Web: ポップアップ / モバイル: GoogleSignIn）
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      return await _auth.signInWithPopup(googleProvider);
    } else {
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

  // Appleログイン（Web: ポップアップ / モバイル: sign_in_with_apple）
  Future<UserCredential?> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com');
      provider.addScope('email');
      provider.addScope('name');
      return await _auth.signInWithPopup(provider);
    } else {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
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

  // アカウント削除（再認証 → Firestoreデータ削除 → Auth削除）
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

    // Firestoreのユーザーデータを削除
    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(uid).delete();

    // 投稿を削除
    final posts = await firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get();
    final batch = firestore.batch();
    for (final doc in posts.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Firebase Authアカウントを削除
    await user.delete();
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
