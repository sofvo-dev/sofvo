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
import 'screens/auth/login_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/home/main_tab_screen.dart';
import 'screens/tournament/tournament_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 招待リンクで渡された大会ID（?t=xxx）
String? pendingTournamentId;

/// セルフチェックイン用の大会ID（?checkin=xxx）
String? pendingCheckInTournamentId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Web URLパラメータ or パスから招待リンクの大会IDを取得
  if (kIsWeb) {
    final uri = Uri.base;
    pendingTournamentId = uri.queryParameters['t'];
    pendingCheckInTournamentId = uri.queryParameters['checkin'];

    // /tournament/:id パスにも対応
    if (pendingTournamentId == null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'tournament') {
      pendingTournamentId = uri.pathSegments[1];
    }
  }

  // Firestoreオフラインキャッシュ（モバイルのみ）
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
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
    } catch (_) {}
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
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

            return const MainTabScreen();
          },
        );
      },
    );
  }
}
