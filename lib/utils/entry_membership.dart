import 'package:cloud_firestore/cloud_firestore.dart';

/// 大会エントリーの参加判定ユーティリティ。
///
/// エントリーへの参加は enteredBy（エントリー操作した人）だけでなく、
/// leaderUid / memberUids（チームメンバー）としての参加もある。
/// enteredBy のみで判定するとチームメンバーとして参加した人が漏れるため、
/// 参加判定は必ずこの関数を使う（tournament_detail_screen の _loadMyTeams と同じ基準）。

/// エントリードキュメントのデータに uid が参加者として含まれるか
bool entryContainsUser(Map<String, dynamic> data, String uid) {
  if (data['enteredBy'] == uid) return true;
  if (data['leaderUid'] == uid) return true;
  final memberUids = data['memberUids'];
  if (memberUids is List && memberUids.contains(uid)) return true;
  return false;
}

/// エントリー一覧スナップショットから、uid が参加者として含まれるエントリーを返す
List<QueryDocumentSnapshot<Map<String, dynamic>>> entriesForUser(
    QuerySnapshot<Map<String, dynamic>> entries, String uid) {
  return entries.docs.where((e) => entryContainsUser(e.data(), uid)).toList();
}
