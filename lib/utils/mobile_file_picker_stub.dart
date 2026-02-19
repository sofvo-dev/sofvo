import 'dart:typed_data';

/// モバイル向けスタブ（WebFilePicker は使用しない）
class WebFilePicker {
  static Future<List<PickedFile>> pickImages() async => [];
}

class PickedFile {
  final String name;
  final Uint8List bytes;
  PickedFile({required this.name, required this.bytes});
}
