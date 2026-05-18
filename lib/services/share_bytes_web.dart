import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<void> shareBytesAsFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
  String? shareText,
  Rect? sharePositionOrigin,
}) async {
  await Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        name: filename,
        mimeType: mimeType,
      ),
    ],
    text: shareText,
  );
}
