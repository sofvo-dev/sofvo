import 'dart:convert';
import 'package:http/http.dart' as http;

class AmazonProduct {
  final String asin;
  final String title;
  final String imageUrl;
  final String detailPageUrl;
  final String affiliateUrl;
  final String? price;

  AmazonProduct({
    required this.asin,
    required this.title,
    required this.imageUrl,
    required this.detailPageUrl,
    required this.affiliateUrl,
    this.price,
  });

  factory AmazonProduct.fromJson(Map<String, dynamic> json) {
    return AmazonProduct(
      asin: json['asin'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      detailPageUrl: json['detailPageUrl'] ?? '',
      affiliateUrl: json['affiliateUrl'] ?? json['detailPageUrl'] ?? '',
      price: json['price'],
    );
  }

  Map<String, dynamic> toJson() => {
    'asin': asin,
    'title': title,
    'imageUrl': imageUrl,
    'detailPageUrl': detailPageUrl,
    'affiliateUrl': affiliateUrl,
    'price': price,
  };
}

/// タイトルから価格を推定（フォールバック用）
String? extractPriceFromTitle(String title) {
  // 「￥5,000」「¥5000」のパターン
  final yenMatch = RegExp(r'[￥¥]\s?([\d,]+)').firstMatch(title);
  if (yenMatch != null) {
    final num = int.tryParse(yenMatch.group(1)!.replaceAll(',', ''));
    if (num != null && num >= 100 && num <= 10000000) {
      return '￥${_formatWithComma(num)}';
    }
  }
  // 「5,000円」「5000円」のパターン
  final enMatch = RegExp(r'([\d,]+)\s*円').firstMatch(title);
  if (enMatch != null) {
    final num = int.tryParse(enMatch.group(1)!.replaceAll(',', ''));
    if (num != null && num >= 100 && num <= 10000000) {
      return '￥${_formatWithComma(num)}';
    }
  }
  return null;
}

String _formatWithComma(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class AmazonSearchService {
  static const _baseUrl =
      'https://us-central1-sofvo-19d84.cloudfunctions.net';

  /// Amazon商品をキーワードで検索
  /// Cloud Functions経由（PA-API → スクレイピング フォールバック）
  static Future<List<AmazonProduct>> searchProducts(String keyword, {int page = 1}) async {
    if (keyword.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/amazonSearch')
        .replace(queryParameters: {'q': keyword, 'page': page.toString()});

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      if (body is List) {
        return body
            .map((item) => AmazonProduct.fromJson(item))
            .toList();
      }
    }

    // エラーメッセージをパースして投げる
    if (response.statusCode >= 400) {
      String message = '検索に失敗しました';
      try {
        final err = json.decode(response.body);
        if (err is Map && err['error'] != null) {
          message = err['error'];
        }
      } catch (_) {}
      throw Exception(message);
    }

    return [];
  }

  /// Amazon URLからASINを抽出
  static String? extractAsin(String url) {
    final patterns = [
      RegExp(r'/dp/([A-Z0-9]{10})'),
      RegExp(r'/gp/product/([A-Z0-9]{10})'),
      RegExp(r'/([A-Z0-9]{10})(?:[/?]|$)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// ASINからリアルタイム価格を取得
  static Future<String?> fetchPrice(String asin) async {
    try {
      final uri = Uri.parse('$_baseUrl/amazonProduct')
          .replace(queryParameters: {'asin': asin});
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['price'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Amazon URLから商品情報を取得（Cloud Functions経由）
  static Future<AmazonProduct?> fetchProductByUrl(String url) async {
    final asin = extractAsin(url);
    if (asin == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/amazonProduct')
          .replace(queryParameters: {'asin': asin});

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AmazonProduct.fromJson(data);
      }
    } catch (_) {
      // フォールバック: ASINから標準画像URLを生成
    }

    return AmazonProduct(
      asin: asin,
      title: '',
      imageUrl: 'https://images-na.ssl-images-amazon.com/images/P/$asin.09.LZZZZZZZ.jpg',
      detailPageUrl: 'https://www.amazon.co.jp/dp/$asin',
      affiliateUrl: 'https://www.amazon.co.jp/dp/$asin',
    );
  }
}
