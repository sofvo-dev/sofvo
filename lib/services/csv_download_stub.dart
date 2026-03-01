import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCsvFile(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, encoding: utf8);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: filename,
  );
}
