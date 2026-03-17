import 'package:web/web.dart' as web;

/// LINEやFacebookなどのアプリ内ブラウザかどうかを判定
bool isInAppBrowser() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('line/') ||
      ua.contains('fbav/') ||
      ua.contains('fban/') ||
      ua.contains('instagram') ||
      ua.contains('twitter');
}
