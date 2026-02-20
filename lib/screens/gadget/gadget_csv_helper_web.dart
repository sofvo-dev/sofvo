import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web環境でのCSVダウンロード
void downloadCsvFile(String csvString, String fileName) {
  // BOM付きUTF-8でExcel互換
  final bom = '\uFEFF';
  final bytes = utf8.encode('$bom$csvString');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
