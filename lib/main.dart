import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/bookmark_notification_service.dart';
import 'services/push_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/home/main_tab_screen.dart';
import 'screens/tournament/tournament_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 招待リンクで渡された大会ID（?t=xxx）
String? pendingTournamentId;

/// セルフチェックイン用の大会ID（?checkin=xxx）
String? pendingCheckInTournamentId;

/// 友達紹介リンクで渡された紹介者UID（?ref=xxx）
String? pendingReferrerUserId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Web URLパラメータ or パスから招待リンクの大会IDを取得
  if (kIsWeb) {
    final uri = Uri.base;
    pendingTournamentId = uri.queryParameters['t'];
    pendingCheckInTournamentId = uri.queryParameters['checkin'];
    pendingReferrerUserId = uri.queryParameters['ref'];

    // /tournament/:id パスにも対応
    if (pendingTournamentId == null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'tournament') {
      pendingTournamentId = uri.pathSegments[1];
    }
  }

  // Firestoreオフラインキャッシュ（モバイルのみ）
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB上限
    );
  }

  // プッシュ通知にグローバルキーを設定
  PushNotificationService.navigatorKey = navigatorKey;
  PushNotificationService.scaffoldMessengerKey = scaffoldMessengerKey;

  runApp(const SofvoApp());
}

class SofvoApp extends StatelessWidget {
  const SofvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      locale: const Locale('ja', 'JP'),
      title: 'Sofvo',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _navigatedToTournament = false;
  bool _processedReferral = false;
  // ストリームをキャッシュしてビルド毎の再サブスクライブを防止
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService().authStateChanges;
  }

  /// 招待リンクの大会へ自動遷移
  Future<void> _navigateToInvitedTournament() async {
    if (_navigatedToTournament || pendingTournamentId == null) return;
    _navigatedToTournament = true;
    final tid = pendingTournamentId!;
    pendingTournamentId = null; // 一度だけ処理

    try {
      final doc = await FirebaseFirestore.instance.collection('tournaments').doc(tid).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      data['id'] = doc.id;

      // 次フレームでpush（buildの最中にnavigateしないように）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: data)),
        );
      });
    } catch (e) {
      debugPrint('招待リンクの大会遷移に失敗: $e');
    }
  }

  /// セルフチェックイン用の自動遷移
  Future<void> _handlePendingCheckIn() async {
    if (pendingCheckInTournamentId == null) return;
    final tid = pendingCheckInTournamentId!;
    pendingCheckInTournamentId = null;

    try {
      final doc = await FirebaseFirestore.instance.collection('tournaments').doc(tid).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      data['id'] = doc.id;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: data, autoCheckIn: true)),
        );
      });
    } catch (e) {
      debugPrint('セルフチェックイン遷移に失敗: $e');
    }
  }

  /// 既存ユーザーが紹介リンクを開いた場合の相互フォロー処理
  Future<void> _handlePendingReferral(String myUid) async {
    if (_processedReferral || pendingReferrerUserId == null) return;
    if (pendingReferrerUserId == myUid) {
      pendingReferrerUserId = null;
      return;
    }
    _processedReferral = true;
    final referrerUid = pendingReferrerUserId!;
    pendingReferrerUserId = null;

    try {
      final firestore = FirebaseFirestore.instance;
      final myRef = firestore.collection('users').doc(myUid);
      final referrerRef = firestore.collection('users').doc(referrerUid);

      // 紹介者が存在するか確認
      final referrerDoc = await referrerRef.get();
      if (!referrerDoc.exists) return;
      final referrerData = referrerDoc.data() ?? {};
      final referrerName = (referrerData['nickname'] ?? '名前なし').toString();

      // 既にフォロー済みかチェック
      final existingFollow = await myRef.collection('following').doc(referrerUid).get();
      if (existingFollow.exists) {
        // 既にフォロー済み → スナックバーで通知
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('$referrerNameさんは既にフォロー済みです'),
              backgroundColor: const Color(0xFF1565C0),
            ),
          );
        });
        return;
      }

      // 自分の情報を取得
      final myDoc = await myRef.get();
      final myData = myDoc.data() ?? {};
      final myNickname = (myData['nickname'] ?? '名前なし').toString();

      // 新規ユーザー → 紹介者 をフォロー
      await myRef.collection('following').doc(referrerUid).set({
        'nickname': referrerName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await referrerRef.collection('followers').doc(myUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 紹介者 → 新規ユーザー をフォロー（既にフォロー済みでなければ）
      final reverseFollow = await referrerRef.collection('following').doc(myUid).get();
      if (!reverseFollow.exists) {
        await referrerRef.collection('following').doc(myUid).set({
          'nickname': myNickname,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await myRef.collection('followers').doc(referrerUid).set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await referrerRef.update({
          'followingCount': FieldValue.increment(1),
        });
        await myRef.update({
          'followersCount': FieldValue.increment(1),
        });
      }

      // カウンター更新（自分→紹介者のフォロー分）
      await myRef.update({
        'followingCount': FieldValue.increment(1),
      });
      await referrerRef.update({
        'followersCount': FieldValue.increment(1),
      });

      // 紹介者に通知
      NotificationService.sendFollowNotification(
        targetUserId: referrerUid,
        senderId: myUid,
        senderName: myNickname,
        senderAvatar: myData['avatarUrl'] ?? '',
      );

      // スナックバーで通知
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('$referrerNameさんと友達になりました！'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      });
    } catch (e) {
      debugPrint('紹介リンクの相互フォロー処理に失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          // 未ログイン時はpendingTournamentIdを保持したままログイン画面へ
          _navigatedToTournament = false;
          // 紹介リンクからのアクセスは新規登録画面を表示
          if (pendingReferrerUserId != null) {
            return const RegisterScreen();
          }
          return const LoginScreen();
        }
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }
            if (!userSnapshot.hasData ||
                !userSnapshot.data!.exists ||
                userSnapshot.data!.get('profileCompleted') != true) {
              return const ProfileSetupScreen();
            }
            BookmarkNotificationService.checkAndNotify(snapshot.data!.uid);
            PushNotificationService.initialize();

            // 招待リンクがあれば大会詳細へ自動遷移
            if (pendingTournamentId != null) {
              _navigateToInvitedTournament();
            }
            // セルフチェックインリンク
            if (pendingCheckInTournamentId != null) {
              _handlePendingCheckIn();
            }
            // 紹介リンク（既存ユーザー向け）
            if (pendingReferrerUserId != null) {
              _handlePendingReferral(snapshot.data!.uid);
            }

            return const MainTabScreen();
          },
        );
      },
    );
  }
}
