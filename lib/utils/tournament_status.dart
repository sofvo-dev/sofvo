/// 大会 Firestore `status` の正規化（アプリ内表記は **エントリー締切** に統一）
String normalizeTournamentStatus(dynamic raw, {bool emptyAsPreparing = true}) {
  if (raw == null || (raw is String && raw.isEmpty)) {
    return emptyAsPreparing ? '準備中' : '';
  }
  final s = raw.toString();
  if (s == 'エントリー締め切') return 'エントリー締切';
  return s;
}
