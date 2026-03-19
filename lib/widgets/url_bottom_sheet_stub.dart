import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ネイティブ（iOS/Android）では外部ブラウザで開く
void showUrlBottomSheet(BuildContext context, String title, String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
