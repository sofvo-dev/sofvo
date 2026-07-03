/// ユーザー検索用の文字列正規化。
///
/// Firestore の `users.nicknameNorm` / `users.searchIdNorm` はこの正規化を
/// かけた値で保存される（functions/index.js の normalizeForSearch と同一仕様。
/// 変更する場合は必ず両方を揃えること）。
///
/// 変換順: 全角英数記号→半角 → カタカナ→ひらがな → 空白除去 → 小文字化
String normalizeForSearch(String s) {
  if (s.isEmpty) return '';
  final buf = StringBuffer();
  for (var c in s.runes) {
    if (c >= 0xFF01 && c <= 0xFF5E) c -= 0xFEE0; // 全角英数記号 → 半角
    if (c >= 0x30A1 && c <= 0x30F6) c -= 0x60; // カタカナ → ひらがな
    if (c == 0x20 || c == 0x3000 || c == 0x09 || c == 0x0A || c == 0x0D) continue; // 空白除去
    buf.writeCharCode(c);
  }
  return buf.toString().toLowerCase();
}

/// 編集距離が1以内か（置換・挿入・削除いずれか1回まで）。
/// 誤字・タイポの救済用。両方とも正規化済みの文字列を渡すこと。
bool isEditDistanceLe1(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  if (a == b) return true;
  // a を短い方に揃える
  if (a.length > b.length) {
    final t = a;
    a = b;
    b = t;
  }
  var i = 0, j = 0;
  var edited = false;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (edited) return false;
    edited = true;
    if (a.length == b.length) {
      i++; // 置換
      j++;
    } else {
      j++; // 挿入（長い方を読み飛ばす）
    }
  }
  return true; // 末尾の残り1文字は1回の編集に収まる
}
