import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> shareBytesAsFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
  String? shareText,
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
