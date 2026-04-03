import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/tournament/tournament_detail_screen.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// グローバルナビゲーターキー（main.dartで設定）
  static GlobalKey<NavigatorState>? navigatorKey;

  /// グローバルScaffoldMessengerキー
  static GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  static Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _saveToken();

        // iOS: フォアグラウンド表示オプション
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        _messaging.onTokenRefresh.listen((token) => _saveTokenToFirestore(token));

        // フォアグラウンドメッセージ → バナー表示
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // バックグラウンドからのタップ → 画面遷移
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        // アプリ終了状態からの起動
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }
      }
    } catch (e) {
      debugPrint('Push notification initialization failed: $e');
    }
  }

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // FCMトークンはprivateサブコレクションに保存（他ユーザーからアクセス不可）
    await _firestore
        .collection('users').doc(uid)
        .collection('private').doc('info')
        .set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// フォアグラウンドでの通知 → SnackBarバナーで表示
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final messengerState = scaffoldMessengerKey?.currentState;
    if (messengerState != null) {
      messengerState.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.title != null)
                Text(notification.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              if (notification.body != null)
                Text(notification.body!,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: const Color(0xFF1B3A5C),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '見る',
            textColor: const Color(0xFFC4A962),
            onPressed: () => _navigateByData(message.data),
          ),
        ),
      );
    }
  }

  /// 通知タップ → 画面遷移
  static void _handleMessageTap(RemoteMessage message) {
    _navigateByData(message.data);
  }

  /// データに基づいて遷移
  static void _navigateByData(Map<String, dynamic> data) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type'] as String?;
    final targetId = data['targetId'] as String?;

    if (type == null) return;

    switch (type) {
      case 'chat':
        if (targetId != null) _navigateToChat(navigator, targetId);
        break;
      case 'follow':
        if (targetId != null) {
          navigator.push(MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: targetId),
          ));
        }
        break;
      case 'like':
      case 'comment':
        // 投稿への遷移（将来実装）
        break;
      case 'tournament_announcement':
      case 'tournament_end':
      case 'waitlist_available':
      case 'deadline_approaching':
      case 'tournament_created':
      case 'slots_low':
        final tournamentId = data['tournamentId'] as String? ?? targetId;
        if (tournamentId != null) _navigateToTournament(navigator, tournamentId);
        break;
      case 'team_join':
      case 'team_leave':
        // チーム画面への遷移（将来実装）
        break;
      case 'official':
        // 公式通知はタップ時に特別遷移なし（通知一覧を開く）
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  /// 大会詳細に遷移
  static Future<void> _navigateToTournament(NavigatorState navigator, String tournamentId) async {
    try {
      final doc = await _firestore.collection('tournaments').doc(tournamentId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      data['id'] = doc.id;
      navigator.push(MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(tournament: data),
      ));
    } catch (e) {
      debugPrint('Failed to navigate to tournament: $e');
    }
  }

  /// チャット画面に遷移（chatIdからメタ情報を取得）
  static Future<void> _navigateToChat(NavigatorState navigator, String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data() ?? {};
      final chatType = (chatData['type'] as String?) ?? 'dm';
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      String chatTitle;
      String? otherUserId;

      if (chatType == 'dm') {
        final memberNames = chatData['memberNames'] as Map<String, dynamic>? ?? {};
        final otherEntry = memberNames.entries.firstWhere(
          (e) => e.key != uid,
          orElse: () => const MapEntry('', 'ユーザー'),
        );
        chatTitle = otherEntry.value as String;
        otherUserId = otherEntry.key.isNotEmpty ? otherEntry.key : null;
      } else {
        chatTitle = (chatData['name'] as String?) ?? 'グループ';
      }

      navigator.push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          chatTitle: chatTitle,
          chatType: chatType,
          otherUserId: otherUserId,
        ),
      ));
    } catch (e) {
      debugPrint('Failed to navigate to chat: $e');
    }
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users').doc(uid)
        .collection('private').doc('info')
        .set({
      'fcmToken': FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}
