import '../services/amazon_search_service.dart';

class AffiliateConfig {
  // ── Amazon アソシエイト ──
  static const String amazonAssociateTag = 'weddingstyl0a-22';

  /// 素のAmazon URLにアソシエイトタグを付与して返す
  /// ASINベースのクリーンなURLを生成
  static String buildAmazonAffiliateUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';

    final asin = AmazonSearchService.extractAsin(rawUrl);
    if (asin != null) {
      return 'https://www.amazon.co.jp/dp/$asin?tag=$amazonAssociateTag';
    }

    // ASINが抽出できない場合は元URLにタグを付与
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;

    final params = Map<String, String>.from(uri.queryParameters);
    params['tag'] = amazonAssociateTag;
    return uri.replace(queryParameters: params).toString();
  }

  // ── 楽天アフィリエイト ──
  // 楽天URLはそのまま使用（手動設定 or 将来API自動生成）
  static String buildRakutenAffiliateUrl(String rakutenUrl) {
    return rakutenUrl;
  }
}
