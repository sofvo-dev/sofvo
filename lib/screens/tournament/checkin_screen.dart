import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';

/// QRコード受付画面（大会主催者用）
/// 2パターン:
///   1. QRコード表示  - 大会QRを表示、キャプテンがスキャンしてチェックイン
///   2. 手動受付      - チェックリストで手動チェック
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
        title: const Text('受付管理', style: TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          tabs: const [
            Tab(text: 'QRコード表示'),
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

  // ━━━ タブ1: QRコード表示（キャプテンがスキャン） ━━━
  Widget _buildParticipantScanTab() {
    // /app は App Links / Universal Links でネイティブアプリにのみ紐づけ（ルートはWebのまま）
    final checkInUrl = 'https://sofvo.com/app?checkin=${widget.tournamentId}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'このQRコードを受付に掲示してください\nキャプテンがスキャンして自動チェックイン',
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
