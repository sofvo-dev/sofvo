import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:sofvo/config/app_theme.dart';

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
  /// filePath: 元画像のファイルパス
  /// 戻り値: クロップ後のバイトデータ（キャンセル時はnull）
  static Future<Uint8List?> cropIconImage(
    String filePath,
    BuildContext context,
  ) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: filePath,
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
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 400, height: 400),
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
