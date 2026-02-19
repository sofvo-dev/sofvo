import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';

/// QRコード受付画面（主催者用）
/// 3パターン:
///   1. 主催者がスキャン  - 主催者がカメラでチームのQRを読み取る
///   2. 参加者がスキャン  - 大会QRを表示、参加者がカメラで読み取ってチェックイン
///   3. 手動受付         - チェックリストで手動チェック
class CheckInScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const CheckInScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('受付管理', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          tabs: const [
            Tab(text: '主催者がスキャン'),
            Tab(text: '参加者がスキャン'),
            Tab(text: '手動受付'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrganizerScanTab(),
          _buildParticipantScanTab(),
          _buildManualCheckInTab(),
        ],
      ),
    );
  }

  // ━━━ タブ1: 主催者がカメラでスキャン ━━━
  // 各チームがQRを表示 → 主催者がカメラで読み取る
  Widget _buildOrganizerScanTab() {
    return Column(
      children: [
        // 到着状況ヘッダー
        _buildArrivalHeader(),
        // スキャンボタン
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openScanner(context),
              icon: const Icon(Icons.qr_code_scanner, size: 22),
              label: const Text('カメラでQRをスキャン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // チェックイン済みリスト
        Expanded(child: _buildCheckInStatusList()),
      ],
    );
  }

  // ━━━ タブ2: 参加者がスキャン（大会QRを表示） ━━━
  Widget _buildParticipantScanTab() {
    final checkInUrl = 'sofvo://checkin/${widget.tournamentId}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'このQRコードを受付に掲示してください\n参加者がスキャンして自動チェックイン',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
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
          const SizedBox(height: 32),
          _buildCheckInStatusList(),
        ],
      ),
    );
  }

  // ━━━ タブ3: 手動受付 ━━━
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
                        border: Border.all(color: isChecked ? AppTheme.success.withOpacity(0.4) : Colors.grey[200]!),
                      ),
                      child: SwitchListTile(
                        value: isChecked,
                        activeColor: AppTheme.success,
                        onChanged: (val) => _toggleManualCheckIn(teamId, teamName, val),
                        title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(isChecked ? '到着済み' : '未到着',
                            style: TextStyle(fontSize: 12, color: isChecked ? AppTheme.success : AppTheme.textHint)),
                        secondary: CircleAvatar(
                          backgroundColor: isChecked ? AppTheme.success.withOpacity(0.1) : Colors.grey[100],
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

  // ━━━ 到着状況ヘッダー ━━━
  Widget _buildArrivalHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tournaments').doc(widget.tournamentId).collection('entries').snapshots(),
      builder: (context, entriesSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('tournaments').doc(widget.tournamentId).collection('checkIns').snapshots(),
          builder: (context, checkInSnap) {
            final total = entriesSnap.data?.docs.length ?? 0;
            final checked = checkInSnap.data?.docs.length ?? 0;
            final allArrived = total > 0 && checked >= total;

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('到着状況', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('$checked / $total チーム',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ])),
                  SizedBox(
                    width: 56, height: 56,
                    child: CircularProgressIndicator(
                      value: total > 0 ? checked / total : 0,
                      strokeWidth: 7,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          allArrived ? AppTheme.success : AppTheme.primaryColor),
                    ),
                  ),
                ]),
                if (allArrived) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                      const SizedBox(width: 8),
                      Text('全チーム到着！大会を開始できます',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                    ]),
                  ),
                ],
              ]),
            );
          },
        );
      },
    );
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
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
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

  // ━━━ カメラスキャナーを開く ━━━
  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QRScannerPage(
          onScanned: (code) async {
            Navigator.pop(context);
            await _handleScannedCode(code);
          },
        ),
      ),
    );
  }

  // ━━━ スキャン結果を処理 ━━━
  Future<void> _handleScannedCode(String code) async {
    // 期待フォーマット: sofvo://checkin/{tournamentId}/{teamId}
    if (!code.startsWith('sofvo://checkin/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無効なQRコードです'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final parts = code.replaceFirst('sofvo://checkin/', '').split('/');
    if (parts.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QRコードの形式が正しくありません'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final tournamentId = parts[0];
    final teamId = parts[1];

    if (tournamentId != widget.tournamentId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この大会のQRコードではありません'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // チーム名取得
    final entrySnap = await _firestore
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('entries')
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();

    if (entrySnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このチームはエントリーしていません'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final teamName = (entrySnap.docs.first.data())['teamName'] ?? '';

    // 重複チェック
    final existing = await _firestore
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('checkIns')
        .where('teamId', isEqualTo: teamId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$teamName はすでにチェックイン済みです'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // チェックイン登録
    await _firestore
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('checkIns')
        .add({
      'teamId': teamId,
      'teamName': teamName,
      'checkedInAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$teamName チェックイン完了！'),
          ]),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

// ━━━ QRスキャナーページ ━━━
class _QRScannerPage extends StatefulWidget {
  final Function(String) onScanned;
  const _QRScannerPage({required this.onScanned});

  @override
  State<_QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<_QRScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QRコードをスキャン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                setState(() => _hasScanned = true);
                widget.onScanned(barcode!.rawValue!);
              }
            },
          ),
          // スキャンガイド枠
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentColor, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // 説明テキスト
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'QRコードを枠内に合わせてください',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
