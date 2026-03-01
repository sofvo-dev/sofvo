import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> downloadCsvFile(String content, String filename) async {
  // BOM付きUTF-8でExcelでも文字化けしない
  final bom = [0xEF, 0xBB, 0xBF];
  final bytes = [...bom, ...utf8.encode(content)];
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
