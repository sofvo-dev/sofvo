import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../config/app_theme.dart';
import '../../services/pdf_generator.dart';
import '../../services/save_image_bytes.dart';
import '../../services/share_bytes.dart';
import '../../services/tournament_summary_data.dart';
import '../../services/tournament_summary_image_service.dart';

/// 大会要項のダウンロード画面。PDF／画像(JPG相当のPNG)を切り替えてプレビューし、
/// そのまま保存・共有できる。
class TournamentSummaryDownloadScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  const TournamentSummaryDownloadScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentSummaryDownloadScreen> createState() => _TournamentSummaryDownloadScreenState();
}

class _TournamentSummaryDownloadScreenState extends State<TournamentSummaryDownloadScreen> {
  bool _isPdf = true;
  late final Future<TournamentSummaryData> _dataFuture;
  Uint8List? _imageBytes;
  bool _loadingImage = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = TournamentSummaryData.build(widget.tournamentId);
  }

  String get _stem {
    var s = widget.tournamentName.trim();
    if (s.isEmpty) s = 'tournament';
    s = s.replaceAll(RegExp(r'[/\\:*?"<>|]+'), '_').replaceAll(RegExp(r'\s+'), '_');
    return s.length > 60 ? s.substring(0, 60) : s;
  }

  Future<void> _generateImage(TournamentSummaryData data) async {
    if (_imageBytes != null || _loadingImage) return;
    setState(() => _loadingImage = true);
    try {
      final bytes = await TournamentSummaryImageService.renderPng(context, data);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _loadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の生成に失敗しました: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _saveImage() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    try {
      await saveImageBytes(bytes, filename: '${_stem}_要項.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真に保存しました'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      try {
        await shareBytesAsFile(bytes,
            filename: '${_stem}_要項.png', mimeType: 'image/png', shareText: '${widget.tournamentName} 大会要項');
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存に失敗しました: $e2'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _shareImage() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    await shareBytesAsFile(bytes,
        filename: '${_stem}_要項.png', mimeType: 'image/png', shareText: '${widget.tournamentName} 大会要項');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('大会要項', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
      ),
      body: FutureBuilder<TournamentSummaryData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          final data = snap.data!;
          if (!_isPdf) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _generateImage(data));
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Expanded(
                  child: _formatChip('PDF', Icons.picture_as_pdf_outlined, _isPdf, () => setState(() => _isPdf = true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _formatChip('画像', Icons.image_outlined, !_isPdf, () => setState(() => _isPdf = false)),
                ),
              ]),
            ),
            Expanded(
              child: _isPdf
                  ? PdfPreview(
                      build: (format) => PdfGenerator().generateTournamentSummaryFromData(data),
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      pdfFileName: '${_stem}_要項.pdf',
                    )
                  : _buildImagePreview(),
            ),
          ]);
        },
      ),
    );
  }

  Widget _formatChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey[300]!),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_loadingImage || _imageBytes == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    return Column(children: [
      Expanded(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(child: Image.memory(_imageBytes!)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareImage,
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('共有'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saveImage,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('保存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}
