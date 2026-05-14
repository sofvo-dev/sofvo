import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_theme.dart';
import '../../services/pdf_generator.dart';

/// 大会のチェックイン受付画面（主催者・編集者向け）
/// - **大会QR表示** … 会場に掲示。参加者は各自の端末でこのQRをスキャンしてチェックインする。
/// - **手動受付** … 主催者がリストから到着をオン／オフする（QRは読まない）。
class CheckInScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final int initialTab;

  const CheckInScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.initialTab = 0,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  bool _exportingQr = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('受付・チェックイン', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          tabs: const [
            Tab(text: '大会QR'),
            Tab(text: '手動受付'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAlivePage(child: _buildParticipantScanTab()),
          _KeepAlivePage(child: _buildManualCheckInTab()),
        ],
      ),
    );
  }

  // ━━━ タブ1: 大会チェックイン用QR（掲示用・参加者がスキャン） ━━━
  Widget _buildParticipantScanTab() {
    // /app は App Links / Universal Links でネイティブアプリにのみ紐づけ（ルートはWebのまま）
    final checkInUrl = 'https://sofvo.com/app?checkin=${widget.tournamentId}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'このQRコードを会場に掲示してください。\n'
            '参加者は各自のスマホのカメラまたはアプリ内の「大会QRをスキャン」で読み取り、チェックインできます。\n'
            '主催者が手動で受付する場合は「手動受付」タブを使います。',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.08), blurRadius: 20)],
            ),
            child: Column(children: [
              QrImageView(
                data: checkInUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(widget.tournamentName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('スキャンしてチェックイン',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingQr ? null : () => _exportCheckInPdf(checkInUrl),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDFで保存'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingQr ? null : () => _exportCheckInPng(checkInUrl),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('画像で保存'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_exportingQr) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _buildCheckInStatusList(),
        ],
      ),
    );
  }

  // ━━━ タブ2: 手動受付 ━━━
  Widget _buildManualCheckInTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('entries')
          .snapshots(),
      builder: (context, entriesSnap) {
        if (!entriesSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        final entries = entriesSnap.data!.docs;
        if (entries.isEmpty) return _emptyState(Icons.group_outlined, 'エントリーチームがありません');

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('checkIns')
              .snapshots(),
          builder: (context, checkInSnap) {
            final checkedIds = <String>{};
            if (checkInSnap.hasData) {
              for (var d in checkInSnap.data!.docs) {
                checkedIds.add((d.data() as Map<String, dynamic>)['teamId'] ?? '');
              }
            }
            final checkedCount = entries.where((e) => checkedIds.contains((e.data() as Map<String, dynamic>)['teamId'])).length;

            return Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Text('到着確認: $checkedCount/${entries.length}チーム',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (checkedCount == entries.length)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                      child: const Text('全員到着', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = entries[i].data() as Map<String, dynamic>;
                    final teamId = entry['teamId'] ?? '';
                    final teamName = entry['teamName'] ?? '不明';
                    final isChecked = checkedIds.contains(teamId);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isChecked ? AppTheme.success.withValues(alpha:0.4) : Colors.grey[200]!),
                      ),
                      child: SwitchListTile(
                        value: isChecked,
                        activeColor: AppTheme.success,
                        onChanged: (val) => _toggleManualCheckIn(teamId, teamName, val),
                        title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(isChecked ? '到着済み' : '未到着',
                            style: TextStyle(fontSize: 12, color: isChecked ? AppTheme.success : AppTheme.textHint)),
                        secondary: CircleAvatar(
                          backgroundColor: isChecked ? AppTheme.success.withValues(alpha:0.1) : Colors.grey[100],
                          child: Icon(isChecked ? Icons.check : Icons.person_outline,
                              color: isChecked ? AppTheme.success : AppTheme.textHint, size: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  Future<Uint8List> _qrPngBytes(String data) async {
    const logical = 320.0;
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(logical, logical));
    final picture = recorder.endRecording();
    final image = await picture.toImage(logical.round(), logical.round());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) {
      throw StateError('QRの画像化に失敗しました');
    }
    return bd.buffer.asUint8List();
  }

  String _safeFileStem(String name) {
    var s = name.trim();
    if (s.isEmpty) s = 'tournament';
    s = s.replaceAll(RegExp(r'[/\\:*?"<>|]+'), '_');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.length > 72) s = s.substring(0, 72);
    return s;
  }

  Future<void> _exportCheckInPdf(String checkInUrl) async {
    setState(() => _exportingQr = true);
    try {
      final png = await _qrPngBytes(checkInUrl);
      final pdfBytes = await PdfGenerator.buildCheckInQrPosterPdf(
        tournamentName: widget.tournamentName,
        checkInUrl: checkInUrl,
        qrPngBytes: png,
      );
      final stem = _safeFileStem(widget.tournamentName);
      await PdfGenerator.sharePdf(pdfBytes, '${stem}_チェックインQR');
    } catch (e, st) {
      debugPrint('checkin pdf export: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDFの作成に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingQr = false);
    }
  }

  Future<void> _exportCheckInPng(String checkInUrl) async {
    setState(() => _exportingQr = true);
    try {
      final png = await _qrPngBytes(checkInUrl);
      final stem = _safeFileStem(widget.tournamentName);
      await Share.shareXFiles(
        [
          XFile.fromData(
            png,
            name: '${stem}_checkin_qr.png',
            mimeType: 'image/png',
          ),
        ],
        text: '${widget.tournamentName} — チェックインQR',
      );
    } catch (e, st) {
      debugPrint('checkin png export: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の共有に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingQr = false);
    }
  }

  // ━━━ チェックイン済みリスト ━━━
  Widget _buildCheckInStatusList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('checkIns')
          .orderBy('checkedInAt', descending: false)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.qr_code, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('まだチェックインしたチームはありません',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final teamName = data['teamName'] ?? '';
            final ts = data['checkedInAt'] as Timestamp?;
            final time = ts != null
                ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                : '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.success.withValues(alpha:0.3)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: AppTheme.success),
                const SizedBox(width: 10),
                Expanded(child: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(time, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleManualCheckIn(String teamId, String teamName, bool value) async {
    if (value) {
      final existing = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('checkIns')
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        await _firestore
            .collection('tournaments')
            .doc(widget.tournamentId)
            .collection('checkIns')
            .add({'teamId': teamId, 'teamName': teamName, 'checkedInAt': FieldValue.serverTimestamp()});
      }
    } else {
      final snap = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('checkIns')
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();
      for (var doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
    ]));
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
