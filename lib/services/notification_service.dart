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
