import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../main.dart' show scaffoldMessengerKey, suppressAuthStateChange;
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  const LoginScreen({super.key, this.onAuthSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithEmail(email, password);
      // ログイン成功 → 親に通知して画面遷移を確実にする
      widget.onAuthSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      String message = 'ログインに失敗しました';
      if (e.toString().contains('invalid-email')) {
        message = 'メールアドレスの形式が正しくありません';
      } else if (e.toString().contains('user-not-found') ||
          e.toString().contains('wrong-password') ||
          e.toString().contains('invalid-credential')) {
        // ユーザー列挙攻撃を防ぐため、アカウント有無を区別しない統一メッセージ
        message = 'メールアドレスまたはパスワードが正しくありません';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUnregisteredSnackBar(String provider) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('この${provider}アカウントは未登録です。\n下の「新規登録」ボタンから登録してください。'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    // 認証状態の変化を一時停止（未登録チェック中の画面ちらつき防止）
    suppressAuthStateChange = true;
    try {
      final result = await AuthService().signInWithGoogle();
      if (result != null) {
        // 未登録のGoogleアカウントでログインしようとした場合は拒否
        if (result.additionalUserInfo?.isNewUser == true) {
          // 自動作成されたアカウントを削除
          await result.user?.delete();
          suppressAuthStateChange = false;
          // グローバルキーでSnackBarを表示（LoginScreenがunmountされても確実に表示）
          _showUnregisteredSnackBar('Google');
          return;
        }
        suppressAuthStateChange = false;
        widget.onAuthSuccess?.call();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Google Sign-In error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('popup-closed-by-user') || errorStr.contains('cancelled')) {
        return; // ユーザーがキャンセル
      }
      String message = 'Googleログインに失敗しました。しばらくしてからもう一度お試しください。';
      if (errorStr.contains('network') || errorStr.contains('unavailable')) {
        message = 'ネットワークに接続できません。接続を確認してください。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      suppressAuthStateChange = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    suppressAuthStateChange = true;
    try {
      final appleResult = await AuthService().signInWithApple();
      if (appleResult != null) {
        // 未登録のAppleアカウントでログインしようとした場合は拒否
        if (appleResult.additionalUserInfo?.isNewUser == true) {
          await appleResult.user?.delete();
          suppressAuthStateChange = false;
          _showUnregisteredSnackBar('Apple');
          return;
        }
        suppressAuthStateChange = false;
        widget.onAuthSuccess?.call();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Apple Sign-In error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('popup-closed-by-user') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('AuthorizationErrorCode.canceled') ||
          errorStr.contains('error 1001')) {
        return; // ユーザーがキャンセル
      }
      String message = 'Appleログインに失敗しました。もう一度お試しください。';
      if (errorStr.contains('operation-not-allowed')) {
        message = 'Appleログインは現在ご利用いただけません。\nメールアドレスまたはGoogleでログインしてください。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      suppressAuthStateChange = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // ── アプリ名 ──
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sof',
                          style: GoogleFonts.montserrat(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                            letterSpacing: 3,
                          ),
                        ),
                        TextSpan(
                          text: 'vo',
                          style: GoogleFonts.montserrat(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentColor,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ソフトバレーボール マッチングアプリ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ── メールアドレス ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'メールアドレスを入力してください';
                      }
                      if (!value.contains('@')) {
                        return '正しいメールアドレスを入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── パスワード ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'パスワードを入力してください';
                      }
                      if (value.length < 6) {
                        return 'パスワードは6文字以上で入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── パスワードを忘れた ──
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _showPasswordResetDialog();
                      },
                      child: Text(
                        'パスワードをお忘れですか？',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── ログインボタン ──
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ログイン'),
                  ),
                  const SizedBox(height: 28),

                  // ── 区切り線 ──
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'または',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Googleログイン ──
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    label: const Text('Googleでログイン'),
                  ),
                  const SizedBox(height: 12),

                  // ── Appleログイン ──
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithApple,
                    icon: const Icon(Icons.apple, size: 22),
                    label: const Text('Appleでログイン'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 新規登録ボタン ──
                  Text(
                    'アカウントをお持ちでない方',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              RegisterScreen(onAuthSuccess: widget.onAuthSuccess),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentColor,
                      side: BorderSide(color: AppTheme.accentColor, width: 1.5),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '新規登録',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordResetDialog() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'パスワードリセット',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '登録済みのメールアドレスを入力してください。\nリセット用のメールを送信します。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('メールアドレスを入力してください'),
                    backgroundColor: AppTheme.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
                return;
              }
              if (!email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('正しいメールアドレスを入力してください'),
                    backgroundColor: AppTheme.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
                return;
              }
              if (true) {
                try {
                  await AuthService().sendPasswordResetEmail(
                      email);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('リセットメールを送信しました'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('メール送信に失敗しました'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 40),
            ),
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }
}
