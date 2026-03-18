/// コンテンツフィルタリングサービス
/// 不適切なコンテンツを検出してユーザーに警告します。
class ContentFilterService {
  static final _ngPatterns = [
    // 暴力・脅迫
    '殺す', '死ね', '殺害',
    // 差別・ヘイト
    'ヘイト',
    // 詐欺・スパム
    '出会い系', '援助交際',
    // 性的コンテンツ
    'アダルト', 'ポルノ',
  ];

  /// テキストに不適切な内容が含まれている場合 true を返します。
  static bool containsProhibitedContent(String text) {
    final lower = text.toLowerCase();
    for (final pattern in _ngPatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
