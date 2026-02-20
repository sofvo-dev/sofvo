import 'package:firebase_auth/firebase_auth.dart';
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
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // ユーザーがキャンセル
      }
      rethrow;
    }
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
