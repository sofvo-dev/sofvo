import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

class WebFilePicker {
  static Future<List<PickedFile>> pickImages() async {
    final completer = Completer<List<PickedFile>>();
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;

    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete([]);
        return;
      }

      final pickedFiles = <PickedFile>[];
      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;
        final bytes = reader.result as Uint8List;
        pickedFiles.add(PickedFile(
          name: file.name,
          bytes: bytes,
        ));
      }
      completer.complete(pickedFiles);
    });

    // キャンセル対応
    input.onAbort.listen((_) => completer.complete([]));

    return completer.future;
  }
}

class PickedFile {
  final String name;
  final Uint8List bytes;

  PickedFile({required this.name, required this.bytes});
}
