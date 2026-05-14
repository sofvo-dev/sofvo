/// 大会チェックイン用のディープリンク（掲示QR・カメラアプリから起動）
///
/// **掲示QR** には [tournamentCheckInQrPayload] を使う（`sofvo://…`）。
/// 純正カメラで読むとブラウザを経由せずネイティブアプリが起動しやすい。
///
/// **https URL**（[tournamentCheckInHttpsUrl]）は Web・Universal Link 用のフォールバック。

String tournamentCheckInQrPayload(String tournamentId) {
  final id = tournamentId.trim();
  if (id.isEmpty) return 'sofvo://checkin/';
  return 'sofvo://checkin/$id';
}

/// `https://sofvo.com/app?checkin=…`（Web・旧QR・手入力用）
String tournamentCheckInHttpsUrl(String tournamentId) {
  final id = tournamentId.trim();
  return 'https://sofvo.com/app?checkin=${Uri.encodeQueryComponent(id)}';
}

/// ネイティブで `app_links` やカメラから届いた URI から大会IDを取り出す。
///
/// 対応形式:
/// - `sofvo://checkin/{tournamentId}`
/// - `sofvo://app?checkin={tournamentId}`
/// - `https://sofvo.com/app?checkin=` および `www`・`/app/` 配下
/// - `https://sofvo.com/?checkin=`（ルート）
String? parseCheckInTournamentIdFromDeepLinkUri(Uri uri) {
  if (uri.scheme == 'sofvo') {
    if (uri.host == 'checkin') {
      for (final seg in uri.pathSegments) {
        final s = seg.trim();
        if (s.isNotEmpty) return Uri.decodeComponent(s);
      }
      return null;
    }
    if (uri.host == 'app') {
      final q = uri.queryParameters['checkin'];
      if (q != null && q.trim().isNotEmpty) return q.trim();
    }
    return null;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  if (host != 'sofvo.com' && host != 'www.sofvo.com') return null;

  final p = uri.path.isEmpty ? '/' : uri.path;
  if (!(p == '/' || p == '/app' || p.startsWith('/app/'))) return null;

  final checkin = uri.queryParameters['checkin'];
  if (checkin == null || checkin.trim().isEmpty) return null;
  return checkin.trim();
}
