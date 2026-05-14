/// 大会 Firestore `status` の正規化
/// - **エントリー締切**（歴史的表記 `エントリー締め切` を吸収）
/// - **大会準備中**（旧 `試合準備中` / `試合準備` を吸収）
String normalizeTournamentStatus(dynamic raw, {bool emptyAsPreparing = true}) {
  if (raw == null || (raw is String && raw.isEmpty)) {
    return emptyAsPreparing ? '準備中' : '';
  }
  final s = raw.toString();
  if (s == 'エントリー締め切') return 'エントリー締切';
  if (s == '試合準備中' || s == '試合準備') return '大会準備中';
  return s;
}
