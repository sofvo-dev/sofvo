import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// メディアファイルの圧縮設定とアップロードを一元管理するサービス
class MediaService {
  // ── 画像圧縮設定 ──
  static const int imageMaxWidth = 800;
  static const int imageMaxHeight = 800;
  static const int imageQuality = 60;

  // ── アバター/アイコン用 ──
  static const int avatarSize = 512;
  static const int avatarQuality = 80;

  // ── ファイルサイズ上限 ──
  static const int maxImageSizeMB = 5;
  static const int maxFileSizeMB = 10;

  /// Firebase Storageに画像をアップロードしてダウンロードURLを返す
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String storagePath,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child(storagePath)
        .child(fileName);

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  /// ファイルサイズのバリデーション（超過時はfalseを返す）
  static bool validateFileSize(int bytes, {int maxMB = 10}) {
    return bytes <= maxMB * 1024 * 1024;
  }

  /// タイムスタンプ付きファイル名を生成
  static String generateFileName(String originalName) {
    return '${DateTime.now().millisecondsSinceEpoch}_$originalName';
  }

  /// ファイルサイズを人間が読める形式に変換
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
