import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 大会収支管理画面
/// 収入（参加費×チーム数）と経費項目を管理し、損益を表示する
class TournamentFinanceScreen extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> tournamentData;
  const TournamentFinanceScreen({super.key, required this.tournamentId, required this.tournamentData});
  @override
  State<TournamentFinanceScreen> createState() => _TournamentFinanceScreenState();
}

class _TournamentFinanceScreenState extends State<TournamentFinanceScreen> {
  final _firestore = FirebaseFirestore.instance;

  /// Firestore の数値は int / double どちらでも返り得るため統一して int にする。
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().replaceAll('¥', '').replaceAll(',', '')) ?? 0;
  }

  static int _entryFeeFor(Map<String, dynamic> td) {
    final raw = td['entryFee'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final s = (raw ?? '0').toString().replaceAll('¥', '').replaceAll(',', '');
    return int.tryParse(s) ?? 0;
  }

  static Map<String, dynamic> _mergeTournamentLive(Map<String, dynamic> base, Map<String, dynamic>? live) {
    final m = Map<String, dynamic>.from(base);
    if (live != null) {
      if (live.containsKey('currentTeams')) m['currentTeams'] = live['currentTeams'];
      if (live.containsKey('entryFee')) m['entryFee'] = live['entryFee'];
    }
    return m;
  }

  CollectionReference get _expensesRef =>
      _firestore.collection('tournaments').doc(widget.tournamentId).collection('expenses');

  // ══════════════════════════════════════
  //  経費 追加 / 編集 / 削除
  // ══════════════════════════════════════

  void _showExpenseDialog({String? docId, String? initialName, int? initialAmount}) {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final amountCtrl = TextEditingController(text: initialAmount != null ? initialAmount.toString() : '');
    final isEditing = docId != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? '経費を編集' : '経費を追加', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: '例: 会場費、ボール代、景品代',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '金額（円）',
                hintStyle: const TextStyle(color: AppTheme.textHint),
                prefixText: '¥ ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (name.isEmpty || amount <= 0) return;

              try {
                final data = <String, dynamic>{'name': name, 'amount': amount, 'updatedAt': FieldValue.serverTimestamp()};
                if (isEditing) {
                  await _expensesRef.doc(docId).update(data);
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  await _expensesRef.add(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存に失敗しました: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEditing ? '更新' : '追加'),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _confirmDelete(String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('経費を削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('「$name」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              try {
                await _expensesRef.doc(docId).delete();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('削除に失敗しました: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Build
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('収支管理')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('tournaments').doc(widget.tournamentId).snapshots(),
        builder: (context, tournSnap) {
          final live = tournSnap.data?.data();
          final td = _mergeTournamentLive(widget.tournamentData, live);
          final entryFeePerTeam = _entryFeeFor(td);
          final currentTeams = _asInt(td['currentTeams']);
          final totalRevenue = entryFeePerTeam * currentTeams;

          return StreamBuilder<QuerySnapshot>(
            stream: _expensesRef.orderBy('createdAt').snapshots(),
            builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '経費の読み込みに失敗しました。\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          final expenses = snapshot.data?.docs ?? [];
          final totalExpenses = expenses.fold<int>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + _asInt(data['amount']);
          });
          final profit = totalRevenue - totalExpenses;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 損益サマリーカード ──
                _buildProfitCard(profit, totalExpenses, totalRevenue),
                const SizedBox(height: 20),

                // ── 収入セクション ──
                _buildSectionHeader('収入', Icons.trending_up_rounded, AppTheme.success),
                const SizedBox(height: 8),
                _buildRevenueCard(entryFeePerTeam, currentTeams, totalRevenue),
                const SizedBox(height: 20),

                // ── 経費セクション ──
                _buildSectionHeader('経費', Icons.trending_down_rounded, AppTheme.error),
                const SizedBox(height: 8),
                ...expenses.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildExpenseItem(doc.id, data['name'] as String? ?? '', _asInt(data['amount']));
                }),
                if (expenses.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textHint),
                        const SizedBox(height: 8),
                        const Text('経費項目がありません', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('下の「＋」ボタンから追加できます', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseDialog(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('経費を追加', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Widget builders
  // ══════════════════════════════════════

  Widget _buildProfitCard(int profit, int totalExpenses, int totalRevenue) {
    final isPositive = profit >= 0;
    final profitColor = isPositive ? AppTheme.success : AppTheme.error;
    final profitLabel = isPositive ? '利益' : '赤字';
    final profitIcon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('損益', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(profitIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                '¥${_formatNumber(profit.abs())}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: profitColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(profitLabel, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('収入合計', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 4),
                      Text('¥${_formatNumber(totalRevenue)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                Expanded(
                  child: Column(
                    children: [
                      const Text('経費合計', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      const SizedBox(height: 4),
                      Text('¥${_formatNumber(totalExpenses)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildRevenueCard(int entryFeePerTeam, int currentTeams, int totalRevenue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildRevenueRow('参加費', '¥${_formatNumber(entryFeePerTeam)} / チーム'),
          const Divider(height: 20),
          _buildRevenueRow('エントリー数', '$currentTeams チーム'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('収入合計', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              Text('¥${_formatNumber(totalRevenue)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildExpenseItem(String docId, String name, int amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_outlined, color: AppTheme.error.withValues(alpha: 0.6), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ),
            Text('¥${_formatNumber(amount)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textHint),
              onSelected: (value) {
                if (value == 'edit') _showExpenseDialog(docId: docId, initialName: name, initialAmount: amount);
                if (value == 'delete') _confirmDelete(docId, name);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('編集')),
                const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    final str = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
