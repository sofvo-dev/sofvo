import 'dart:convert';
import 'package:http/http.dart' as http;

class AmazonProduct {
  final String asin;
  final String title;
  final String imageUrl;
  final String detailPageUrl;
  final String? price;

  AmazonProduct({
    required this.asin,
    required this.title,
    required this.imageUrl,
    required this.detailPageUrl,
    this.price,
  });

  factory AmazonProduct.fromJson(Map<String, dynamic> json) {
    return AmazonProduct(
      asin: json['asin'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      detailPageUrl: json['detailPageUrl'] ?? '',
      price: json['price'],
    );
  }

  Map<String, dynamic> toJson() => {
    'asin': asin,
    'title': title,
    'imageUrl': imageUrl,
    'detailPageUrl': detailPageUrl,
    'price': price,
  };
}

class AmazonSearchService {
  static const _baseUrl =
      'https://us-central1-sofvo-19d84.cloudfunctions.net';

  /// Amazon商品をキーワードで検索
  /// Cloud Functions経由（PA-API → スクレイピング フォールバック）
  static Future<List<AmazonProduct>> searchProducts(String keyword) async {
    if (keyword.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/amazonSearch')
        .replace(queryParameters: {'q': keyword});

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
    );
  }
}
