import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> sendLikeNotification({
    required String postOwnerId,
    required String senderId,
    required String senderName,
    String senderAvatar = '',
    required String postId,
  }) async {
    if (postOwnerId == senderId) return;
    await _firestore
        .collection('users')
        .doc(postOwnerId)
        .collection('notifications')
        .add({
      'type': 'like',
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'message': 'があなたの投稿にいいねしました',
      'postId': postId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendCommentNotification({
    required String postOwnerId,
    required String senderId,
    required String senderName,
    String senderAvatar = '',
    required String postId,
    required String commentText,
  }) async {
    if (postOwnerId == senderId) return;
    final preview = commentText.length > 30
        ? '${commentText.substring(0, 30)}...'
        : commentText;
    await _firestore
        .collection('users')
        .doc(postOwnerId)
        .collection('notifications')
        .add({
      'type': 'comment',
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'message': 'がコメントしました: $preview',
      'postId': postId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendFollowNotification({
    required String targetUserId,
    required String senderId,
    required String senderName,
    String senderAvatar = '',
  }) async {
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
      'type': 'follow',
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'message': 'があなたをフォローしました',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 大会終了時に全参加者へ通知 + タイムラインに自動投稿
  static Future<void> sendTournamentEndNotification({
    required String tournamentId,
    required String tournamentName,
    required String tournamentDate,
    required String organizerId,
    required String organizerName,
  }) async {
    // 参加チーム一覧を取得
    final entries = await _firestore
        .collection('tournaments').doc(tournamentId)
        .collection('entries').get();

    // 全参加者のUIDを収集（重複除外）
    final participantUids = <String>{};
    for (final doc in entries.docs) {
      final data = doc.data();
      final memberUids = data['memberUids'];
      if (memberUids is List) {
        for (final uid in memberUids) {
          if (uid is String && uid.isNotEmpty) participantUids.add(uid);
        }
      }
      final enteredBy = data['enteredBy'] as String?;
      if (enteredBy != null && enteredBy.isNotEmpty) participantUids.add(enteredBy);
    }

    // 優勝チーム情報を取得（bracketの決勝 or standings 1位）
    String winnerTeamName = '';
    try {
      final brackets = await _firestore
          .collection('tournaments').doc(tournamentId)
          .collection('brackets').get();
      if (brackets.docs.isNotEmpty) {
        final bracketId = brackets.docs.first.id;
        final matches = await _firestore
            .collection('tournaments').doc(tournamentId)
            .collection('brackets').doc(bracketId)
            .collection('matches').orderBy('matchNumber', descending: true).limit(1).get();
        if (matches.docs.isNotEmpty) {
          final matchData = matches.docs.first.data();
          final result = matchData['result'] as Map<String, dynamic>?;
          if (result != null && result['winner'] != null) {
            winnerTeamName = (result['winner'] as String?) ?? '';
          }
        }
      }
    } catch (_) {}

    final resultMessage = winnerTeamName.isNotEmpty
        ? '「$tournamentName」が終了しました！優勝: $winnerTeamName'
        : '「$tournamentName」が終了しました！結果を確認しましょう';

    // 全参加者に通知を送信
    final batch = _firestore.batch();
    for (final uid in participantUids) {
      final notifRef = _firestore
          .collection('users').doc(uid)
          .collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'tournament_end',
        'senderId': organizerId,
        'senderName': organizerName,
        'message': resultMessage,
        'tournamentId': tournamentId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // タイムラインに自動投稿（主催者名義）
    final postText = winnerTeamName.isNotEmpty
        ? '🏆「$tournamentName」($tournamentDate) が終了しました！\n\n優勝: $winnerTeamName\n\nご参加ありがとうございました！'
        : '「$tournamentName」($tournamentDate) が終了しました！\n\nご参加ありがとうございました！';

    final userDoc = await _firestore.collection('users').doc(organizerId).get();
    final avatarUrl = (userDoc.data()?['avatarUrl'] ?? '') as String;

    await _firestore.collection('posts').add({
      'userId': organizerId,
      'userNickname': organizerName,
      'userAvatarUrl': avatarUrl,
      'text': postText,
      'images': <String>[],
      'likesCount': 0,
      'commentsCount': 0,
      'autoGenerated': true,
      'tournamentId': tournamentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 大会お知らせ通知（主催者→全参加者）
  static Future<void> sendTournamentAnnouncement({
    required String tournamentId,
    required String tournamentName,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final entries = await _firestore
        .collection('tournaments').doc(tournamentId)
        .collection('entries').get();

    final participantUids = <String>{};
    for (final doc in entries.docs) {
      final data = doc.data();
      final memberUids = data['memberUids'];
      if (memberUids is List) {
        for (final uid in memberUids) {
          if (uid is String && uid.isNotEmpty) participantUids.add(uid);
        }
      }
      final enteredBy = data['enteredBy'] as String?;
      if (enteredBy != null && enteredBy.isNotEmpty) participantUids.add(enteredBy);
    }

    final preview = message.length > 40 ? '${message.substring(0, 40)}...' : message;
    final batch = _firestore.batch();
    for (final uid in participantUids) {
      if (uid == senderId) continue;
      final notifRef = _firestore
          .collection('users').doc(uid)
          .collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'tournament_announcement',
        'senderId': senderId,
        'senderName': senderName,
        'message': '[$tournamentName] $preview',
        'tournamentId': tournamentId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// キャンセル待ち通知（空きが出た場合）
  static Future<void> sendWaitlistNotification({
    required String targetUserId,
    required String tournamentId,
    required String tournamentName,
  }) async {
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
      'type': 'waitlist_available',
      'senderId': 'system',
      'senderName': 'システム',
      'senderAvatar': '',
      'message': '「$tournamentName」に空きが出ました！エントリーしましょう',
      'tournamentId': tournamentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<int> unreadCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
