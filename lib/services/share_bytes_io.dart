import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// PNG 等を一時ファイルに書き出してから共有（iOS で [XFile.fromData] だけだと失敗しやすい）
Future<void> shareBytesAsFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
  String? shareText,
}) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  await File(path).writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(path, mimeType: mimeType)],
    text: shareText,
  );
}
