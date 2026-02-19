import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザー
  User? get currentUser => _auth.currentUser;

  // 認証状態の変化を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // メール＆パスワードでログイン
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // メール＆パスワードで新規登録
  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Googleログイン（v7対応）
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Firebase Auth のポップアップフローを使用
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    }

    // Mobile: google_sign_in v7 API
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();
    final account = await googleSignIn.authenticate();
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  // Appleログイン
  Future<UserCredential> signInWithApple() async {
    final provider = OAuthProvider('apple.com');
    provider.addScope('email');
    provider.addScope('name');
    return await _auth.signInWithProvider(provider);
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
