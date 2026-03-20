import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../config/app_theme.dart';
import '../../main.dart' show suppressAuthStateChange;
import '../../services/auth_service.dart';
import '../../widgets/url_bottom_sheet.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  const RegisterScreen({super.key, this.onAuthSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// Google/Apple登録時に利用規約への同意をポップアップで確認
  Future<bool> _confirmTermsAgreement() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('利用規約への同意',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '続行すると、以下に同意したものとみなされます。',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => showUrlBottomSheet(
                context,
                '利用規約（EULA）',
                'https://sofvo-19d84.web.app/terms.html',
              ),
              child: const Text(
                '利用規約（EULA）',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => showUrlBottomSheet(
                context,
                'プライバシーポリシー',
                'https://sofvo-19d84.web.app/privacy.html',
              ),
              child: const Text(
                'プライバシーポリシー',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('同意して続行'),
          ),
        ],
      ),
    );
    return agreed == true;
  }

  /// 既存アカウントが見つかった場合の確認ダイアログ
  Future<bool> _showExistingAccountDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('既に登録済みです',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'このアカウントは既に登録されています。\nそのままログインしますか？',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログインする'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _registerWithGoogle() async {
    if (!await _confirmTermsAgreement()) return;
    setState(() => _isLoading = true);
    suppressAuthStateChange = true;
    try {
      final result = await AuthService().signInWithGoogle();
      if (result != null) {
        final isNewUser = result.additionalUserInfo?.isNewUser ?? true;
        if (!isNewUser && mounted) {
          // 既存アカウント → 確認ダイアログ
          final proceed = await _showExistingAccountDialog();
          if (!proceed) {
            await AuthService().signOut();
            suppressAuthStateChange = false;
            return;
          }
        }
        suppressAuthStateChange = false;
        widget.onAuthSuccess?.call();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        suppressAuthStateChange = false;
      }
    } catch (e) {
      suppressAuthStateChange = false;
      if (!mounted) return;
      debugPrint('Google Sign-In error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('popup-closed-by-user') ||
          errorStr.contains('cancelled')) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google: $errorStr',
              maxLines: 5, overflow: TextOverflow.ellipsis),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithApple() async {
    if (!await _confirmTermsAgreement()) return;
    setState(() => _isLoading = true);
    suppressAuthStateChange = true;
    try {
      final appleResult = await AuthService().signInWithApple();
      if (appleResult != null) {
        final isNewUser = appleResult.additionalUserInfo?.isNewUser ?? true;
        if (!isNewUser && mounted) {
          final proceed = await _showExistingAccountDialog();
          if (!proceed) {
            await AuthService().signOut();
            suppressAuthStateChange = false;
            return;
          }
        }
        suppressAuthStateChange = false;
        widget.onAuthSuccess?.call();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        suppressAuthStateChange = false;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      suppressAuthStateChange = false;
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (!mounted) return;
      debugPrint('Apple Sign-In authorization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Apple登録に失敗しました'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      suppressAuthStateChange = false;
      if (!mounted) return;
      debugPrint('Apple Sign-In error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('popup-closed-by-user') ||
          errorStr.contains('cancelled')) {
        return;
      }
      String message = 'Apple登録に失敗しました';
      if (errorStr.contains('operation-not-allowed')) {
        message = 'Apple登録は現在ご利用いただけません。\nメールアドレスまたはGoogleで登録してください。';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    suppressAuthStateChange = true;
    try {
      await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      suppressAuthStateChange = false;
      widget.onAuthSuccess?.call();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      suppressAuthStateChange = false;
      if (!mounted) return;
      String message = 'アカウント作成に失敗しました';
      if (e.toString().contains('email-already-in-use')) {
        message = 'このメールアドレスは既に登録済みです。ログイン画面からお試しください';
      } else if (e.toString().contains('weak-password')) {
        message = 'パスワードが弱すぎます（8文字以上で英数字を含めてください）';
      } else if (e.toString().contains('invalid-email')) {
        message = 'メールアドレスの形式が正しくありません';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('新規登録'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 32),

                // ── アイコン ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'アカウントを作成',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'メールアドレスとパスワードを入力してください',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 40),

                // ── メールアドレス ──
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    if (!v.contains('@')) {
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
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (v.length < 6) {
                      return 'パスワードは6文字以上で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── パスワード確認 ──
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'パスワード（確認）',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword =
                            !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'パスワードを再入力してください';
                    }
                    if (v != _passwordController.text) {
                      return 'パスワードが一致しません';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── 登録ボタン ──
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('アカウントを作成'),
                ),
                const SizedBox(height: 28),

                // ── 区切り線 ──
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

                // ── Google登録 ──
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _registerWithGoogle,
                  icon: Image.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.g_mobiledata, size: 24),
                  ),
                  label: const Text('Googleで登録'),
                ),
                const SizedBox(height: 12),

                // ── Apple登録 ──
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _registerWithApple,
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text('Appleで登録'),
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
                const SizedBox(height: 20),

                // ── プライバシーポリシー・利用規約 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => showUrlBottomSheet(
                        context,
                        '利用規約（EULA）',
                        'https://sofvo-19d84.web.app/terms.html',
                      ),
                      child: const Text(
                        '利用規約',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '｜',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textHint,
                      ),
                    ),
                    TextButton(
                      onPressed: () => showUrlBottomSheet(
                        context,
                        'プライバシーポリシー',
                        'https://sofvo-19d84.web.app/privacy.html',
                      ),
                      child: const Text(
                        'プライバシーポリシー',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── ログインへ戻る ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '既にアカウントをお持ちの方は',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'ログイン',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
