import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sofvo/config/app_theme.dart';
import 'package:sofvo/widgets/web_image_cropper.dart';

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

  /// 画像を円形にクロップするUIを表示し、クロップ後のバイトデータを返す
  /// picked: image_pickerで取得したXFile
  /// 戻り値: クロップ後のバイトデータ（キャンセル時はnull）
  static Future<Uint8List?> cropIconImage(
    XFile picked,
    BuildContext context,
  ) async {
    // Web環境: image_cropperのcropper.jsがblob URLを読み込めないため
    // 純Flutter製のクロッパーを使用
    if (kIsWeb) {
      final imageBytes = await picked.readAsBytes();
      if (!context.mounted) return null;
      return WebImageCropperDialog.show(
        context,
        imageBytes: imageBytes,
        outputSize: avatarSize,
      );
    }

    // ネイティブ環境: image_cropperを使用
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: avatarQuality,
      maxWidth: avatarSize,
      maxHeight: avatarSize,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '画像を切り抜き',
          toolbarColor: AppTheme.primaryColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.accentColor,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '画像を切り抜き',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return null;
    return cropped.readAsBytes();
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
