import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sofvo/config/app_theme.dart';

/// Web環境用の円形画像クロッパー
/// InteractiveViewerを使ってピンチズーム・パンに対応
class WebImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final int outputSize;

  const WebImageCropperDialog({
    super.key,
    required this.imageBytes,
    this.outputSize = 512,
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    int outputSize = 512,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WebImageCropperDialog(
          imageBytes: imageBytes,
          outputSize: outputSize,
        ),
      ),
    );
  }

  @override
  State<WebImageCropperDialog> createState() => _WebImageCropperDialogState();
}

class _WebImageCropperDialogState extends State<WebImageCropperDialog> {
  final _transformController = TransformationController();
  ui.Image? _image;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _crop() async {
    if (_image == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final bytes = await _performCrop();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('切り抜きに失敗しました')),
        );
      }
    }
  }

  Future<Uint8List> _performCrop() async {
    final image = _image!;
    final outputSize = widget.outputSize;

    // Get the viewport size (the visible crop area)
    final renderBox = _cropAreaKey.currentContext!.findRenderObject()
        as RenderBox;
    final viewSize = renderBox.size;
    final cropDiameter = min(viewSize.width, viewSize.height);

    // Get the transformation matrix
    final matrix = _transformController.value;
    final inv = Matrix4.inverted(matrix);

    // Calculate the center of the viewport in image coordinates
    final centerX = viewSize.width / 2;
    final centerY = viewSize.height / 2;

    // Calculate image scale to fit viewport
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    final baseScale = min(viewSize.width / imgW, viewSize.height / imgH);

    // Offset used to center the image in the viewport
    final offsetX = (viewSize.width - imgW * baseScale) / 2;
    final offsetY = (viewSize.height - imgH * baseScale) / 2;

    // Transform viewport center back to image coordinates
    final halfCrop = cropDiameter / 2;

    // The crop rect in viewport coordinates
    final cropLeft = centerX - halfCrop;
    final cropTop = centerY - halfCrop;

    // Transform through inverse matrix to get pre-transform coordinates
    final tl = MatrixUtils.transformPoint(
        inv, Offset(cropLeft, cropTop));
    final br = MatrixUtils.transformPoint(
        inv, Offset(cropLeft + cropDiameter, cropTop + cropDiameter));

    // Convert from viewport coordinates (with base scale) to image pixel coords
    final srcLeft = ((tl.dx - offsetX) / baseScale).clamp(0, imgW);
    final srcTop = ((tl.dy - offsetY) / baseScale).clamp(0, imgH);
    final srcRight = ((br.dx - offsetX) / baseScale).clamp(0, imgW);
    final srcBottom = ((br.dy - offsetY) / baseScale).clamp(0, imgH);

    final srcRect = Rect.fromLTRB(
      srcLeft.toDouble(),
      srcTop.toDouble(),
      srcRight.toDouble(),
      srcBottom.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0,
        outputSize.toDouble(), outputSize.toDouble());

    // Draw cropped image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Clip to circle
    canvas.clipPath(
      Path()..addOval(dstRect),
    );
    canvas.drawImageRect(image, srcRect, dstRect, Paint());

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outputSize, outputSize);
    final byteData = await cropped.toByteData(
        format: ui.ImageByteFormat.png);
    cropped.dispose();

    return byteData!.buffer.asUint8List();
  }

  final _cropAreaKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('画像を切り抜き'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _crop,
                ),
        ],
      ),
      body: _image == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final cropSize = min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                ) * 0.8;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Image with pan/zoom
                    SizedBox(
                      key: _cropAreaKey,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.5,
                        maxScale: 5.0,
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Circle overlay mask
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(constraints.maxWidth,
                            constraints.maxHeight),
                        painter: _CircleOverlayPainter(cropSize),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _CircleOverlayPainter extends CustomPainter {
  final double cropSize;
  _CircleOverlayPainter(this.cropSize);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = cropSize / 2;

    // Draw semi-transparent overlay with circle cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Draw circle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
