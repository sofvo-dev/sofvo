import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';

/// QRコード受付画面（主催者用）
/// 3パターン:
///   1. チーム代表者読み取り - 各チームにQRを表示、主催者がリスト確認
///   2. 主催者読み取り       - 大会QRを表示、参加者がスキャンしてチェックイン
///   3. 手動受付            - チェックリストで手動チェック
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
        title: Text('受付管理', style: const TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          tabs: const [
            Tab(text: 'チーム代表読み取り'),
            Tab(text: '大会QR表示'),
            Tab(text: '手動受付'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamQRTab(),
          _buildOrganizerQRTab(),
          _buildManualCheckInTab(),
        ],
      ),
    );
  }

  // ━━━ タブ1: チーム代表者読み取り ━━━
  // 各チームのQRコードを表示。チーム代表者がスマホで表示→主催者が確認してチェックイン
  Widget _buildTeamQRTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('entries')
          .snapshots(),
      builder: (context, entriesSnap) {
        if (!entriesSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final entries = entriesSnap.data!.docs;
        if (entries.isEmpty) {
          return _emptyState(Icons.group_outlined, 'エントリーチームがありません');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('checkIns')
              .snapshots(),
          builder: (context, checkInSnap) {
            final checkedTeamIds = <String>{};
            if (checkInSnap.hasData) {
              for (var doc in checkInSnap.data!.docs) {
                checkedTeamIds.add((doc.data() as Map<String, dynamic>)['teamId'] ?? '');
              }
            }

            final checkedCount = entries.where((e) =>
                checkedTeamIds.contains((e.data() as Map<String, dynamic>)['teamId'])).length;

            return Column(
              children: [
                // 到着状況サマリー
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('到着状況', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text('$checkedCount / ${entries.length} チーム',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      CircularProgressIndicator(
                        value: entries.isEmpty ? 0 : checkedCount / entries.length,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            checkedCount == entries.length ? AppTheme.success : AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                if (checkedCount == entries.length)
                  Container(
                    color: AppTheme.success.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                      const SizedBox(width: 8),
                      Text('全チーム到着！大会を開始できます',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                    ]),
                  ),
                // チームリスト
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final entry = entries[i].data() as Map<String, dynamic>;
                      final teamId = entry['teamId'] ?? '';
                      final teamName = entry['teamName'] ?? '不明';
                      final isChecked = checkedTeamIds.contains(teamId);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isChecked ? AppTheme.success.withOpacity(0.4) : Colors.grey[200]!),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isChecked
                                ? AppTheme.success.withOpacity(0.1)
                                : AppTheme.primaryColor.withOpacity(0.1),
                            child: Text(
                              teamName.isNotEmpty ? teamName[0] : '?',
                              style: TextStyle(
                                  color: isChecked ? AppTheme.success : AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(teamName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: isChecked ? TextDecoration.none : null)),
                          trailing: isChecked
                              ? Chip(
                                  label: const Text('到着', style: TextStyle(fontSize: 11, color: Colors.white)),
                                  backgroundColor: AppTheme.success,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                )
                              : TextButton(
                                  onPressed: () => _showTeamQR(teamId, teamName),
                                  child: const Text('QRを表示'),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ━━━ タブ2: 大会QR表示（参加者がスキャン→チェックイン） ━━━
  Widget _buildOrganizerQRTab() {
    // 大会IDをQRコード化。参加者がスキャンしてチェックイン
    final checkInUrl = 'sofvo://checkin/${widget.tournamentId}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('このQRコードを受付に掲示してください',
              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: checkInUrl,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(widget.tournamentName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('参加チームがスキャンしてチェックイン',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 到着チームリスト
          _buildCheckInList(),
        ],
      ),
    );
  }

  Widget _buildCheckInList() {
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
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text('まだチェックインしたチームはありません',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('チェックイン済み（${docs.length}チーム）',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final teamName = data['teamName'] ?? '';
              final ts = data['checkedInAt'] as Timestamp?;
              final time = ts != null
                  ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
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
            }),
          ],
        );
      },
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
        if (!entriesSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        final entries = entriesSnap.data!.docs;
        if (entries.isEmpty) {
          return _emptyState(Icons.group_outlined, 'エントリーチームがありません');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('checkIns')
              .snapshots(),
          builder: (context, checkInSnap) {
            final checkedTeamIds = <String>{};
            if (checkInSnap.hasData) {
              for (var doc in checkInSnap.data!.docs) {
                checkedTeamIds.add((doc.data() as Map<String, dynamic>)['teamId'] ?? '');
              }
            }

            final checkedCount = entries.where((e) =>
                checkedTeamIds.contains((e.data() as Map<String, dynamic>)['teamId'])).length;

            return Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('到着確認: $checkedCount/${entries.length}チーム',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (checkedCount == entries.length)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.success, borderRadius: BorderRadius.circular(8)),
                          child: const Text('全員到着', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
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
                      final isChecked = checkedTeamIds.contains(teamId);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isChecked ? AppTheme.success.withOpacity(0.4) : Colors.grey[200]!),
                        ),
                        child: SwitchListTile(
                          value: isChecked,
                          activeColor: AppTheme.success,
                          onChanged: (val) => _toggleManualCheckIn(teamId, teamName, val),
                          title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(isChecked ? '到着済み' : '未到着',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isChecked ? AppTheme.success : AppTheme.textHint)),
                          secondary: CircleAvatar(
                            backgroundColor: isChecked
                                ? AppTheme.success.withOpacity(0.1)
                                : Colors.grey[100],
                            child: Icon(
                                isChecked ? Icons.check : Icons.person_outline,
                                color: isChecked ? AppTheme.success : AppTheme.textHint,
                                size: 20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ━━━ QRモーダル（チーム代表者向け） ━━━
  void _showTeamQR(String teamId, String teamName) {
    final qrData = 'sofvo://checkin/${widget.tournamentId}/$teamId';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(teamName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('主催者にこのQRを見せてください',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _checkInTeam(teamId, teamName);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('$teamName のチェックインを確認しました'),
                          backgroundColor: AppTheme.success),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('チェックインを確認', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkInTeam(String teamId, String teamName) async {
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
          .add({
        'teamId': teamId,
        'teamName': teamName,
        'checkedInAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _toggleManualCheckIn(String teamId, String teamName, bool value) async {
    if (value) {
      await _checkInTeam(teamId, teamName);
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
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
      ]),
    );
  }
}
