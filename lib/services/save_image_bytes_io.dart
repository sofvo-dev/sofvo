import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:gal/gal.dart';

/// チェックインQRなどを端末の写真ライブラリに保存（iOS / Android）
Future<void> saveImageBytes(
  Uint8List bytes, {
  required String filename,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) {
    throw UnsupportedError('この端末では写真ライブラリへの直接保存に対応していません');
  }

  var hasAccess = await Gal.hasAccess(toAlbum: true);
  if (!hasAccess) {
    hasAccess = await Gal.requestAccess(toAlbum: true);
  }
  if (!hasAccess) {
    throw StateError('写真ライブラリへのアクセスが許可されていません。設定アプリから許可してください。');
  }

  await Gal.putImageBytes(bytes, name: _galImageName(filename));
}

String _galImageName(String filename) {
  var base = filename.trim();
  final dot = base.lastIndexOf('.');
  if (dot > 0) base = base.substring(0, dot);
  if (base.isEmpty) return 'checkin_qr';
  return base.length > 80 ? base.substring(0, 80) : base;
}
