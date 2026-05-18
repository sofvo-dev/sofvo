import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// PNG 等を一時ファイルに書き出してから共有（iOS で [XFile.fromData] だけだと失敗しやすい）
Future<void> shareBytesAsFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
  String? shareText,
  Rect? sharePositionOrigin,
}) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/${_tempShareFilename(filename)}';
  await File(path).writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(path, mimeType: mimeType, name: filename)],
    text: shareText,
    sharePositionOrigin: sharePositionOrigin,
  );
}

/// 一時パスは ASCII のみ（日本語ファイル名で share が失敗する端末がある）
String _tempShareFilename(String filename) {
  final ext = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')) : '';
  return 'sofvo_share_${DateTime.now().millisecondsSinceEpoch}$ext';
}
