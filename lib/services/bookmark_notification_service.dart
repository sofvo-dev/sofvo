import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkNotificationService {
  static Future<void> checkAndNotify(String uid) async {
    final bookmarks = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('bookmarks').get();

    for (final bm in bookmarks.docs) {
      final data = bm.data();
      final type = data['type'] ?? '';
      if (type != 'tournament') continue;

      final tournamentId = data['targetId'] ?? '';
      if (tournamentId.isEmpty) continue;

      final tSnap = await FirebaseFirestore.instance
          .collection('tournaments').doc(tournamentId).get();
      if (!tSnap.exists) continue;

      final tData = tSnap.data()!;
      final status = tData['status'] ?? '';
      if (status != '募集中') continue;

      final notifications = <String>[];

      // 締切チェック
      final deadline = tData['deadline'] ?? '';
      if (deadline.toString().isNotEmpty) {
        try {
          final parts = deadline.toString().split('/');
          if (parts.length >= 3) {
            final deadlineDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            final daysLeft = deadlineDate.difference(DateTime.now()).inDays;
            if (daysLeft <= 3 && daysLeft >= 0) {
              notifications.add('deadline');
            }
          }
        } catch (_) {}
      }

      // 残り枠チェック
      final currentTeams = tData['currentTeams'] ?? 0;
      final maxTeams = tData['maxTeams'] ?? 8;
      final remaining = maxTeams - currentTeams;
      if (remaining <= 2 && remaining > 0) {
        notifications.add('slots');
      }

      // 通知フラグ更新
      if (notifications.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('bookmarks').doc(bm.id)
            .update({
          'alerts': notifications,
          'lastChecked': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('bookmarks').doc(bm.id)
            .update({
          'alerts': [],
          'lastChecked': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<void> toggleBookmark({
    required String uid,
    required String targetId,
    required String type,
    required Map<String, dynamic> metadata,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('bookmarks');

    final existing = await ref
        .where('targetId', isEqualTo: targetId)
        .where('type', isEqualTo: type).limit(1).get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.delete();
      print('BOOKMARK REMOVED: \$targetId');
      return;
    }

    print('BOOKMARK ADDING: \$targetId type=\$type');
    await ref.add({
      'targetId': targetId,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'alerts': [],
      ...metadata,
    });
    print('BOOKMARK ADDED: \$targetId');
  }

  static Stream<QuerySnapshot> bookmarkStream(String uid, String type) {
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('bookmarks')
        .where('type', isEqualTo: type)
        .snapshots();
  }

  static Future<bool> isBookmarked(String uid, String targetId, String type) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('bookmarks')
        .where('targetId', isEqualTo: targetId)
        .where('type', isEqualTo: type).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
