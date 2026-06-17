import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 任意のウィジェットを画面に表示せずに PNG 画像（バイト列）へ変換する。
///
/// Overlay にオフスクリーン（画面外）で一瞬だけ描画し、RepaintBoundary 経由で
/// キャプチャするため、安定した公開APIだけで実装している。
///
/// [size] は論理ピクセルのキャンバスサイズ。[pixelRatio] を掛けた解像度で出力される。
/// 既定は 1080x1350（4:5・Instagram カルーセル推奨サイズ）。
Future<Uint8List> captureWidgetToPng(
  BuildContext context, {
  required Widget child,
  Size size = const Size(1080, 1350),
  double pixelRatio = 1.0,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final repaintKey = GlobalKey();

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // 画面外に配置（レイアウト・描画はされるが見えない）
      left: -(size.width) - 100,
      top: 0,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  try {
    // レイアウト・描画とフォント反映を待つ
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('画像の描画に失敗しました');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('画像の書き出しに失敗しました');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
