import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../config/affiliate_config.dart';
import 'gadget_register_screen.dart';

// Web環境でのみCSVダウンロードヘルパーをインポート
import 'gadget_csv_helper.dart' if (dart.library.js_interop) 'gadget_csv_helper_web.dart';

class GadgetListScreen extends StatefulWidget {
  const GadgetListScreen({super.key});

  @override
  State<GadgetListScreen> createState() => _GadgetListScreenState();
}

class _GadgetListScreenState extends State<GadgetListScreen> {
  String _filterCategory = 'すべて';
  bool _isSpreadsheetView = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── ヘッダー ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 12),
                      const Text('ガジェット管理',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const Spacer(),
                      // 表示切り替え
                      IconButton(
                        icon: Icon(
                          _isSpreadsheetView ? Icons.grid_view : Icons.table_chart_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        tooltip: _isSpreadsheetView ? 'カード表示' : 'スプレッドシート表示',
                        onPressed: () => setState(() => _isSpreadsheetView = !_isSpreadsheetView),
                      ),
                      // CSV出力
                      IconButton(
                        icon: const Icon(Icons.download_outlined, color: AppTheme.primaryColor),
                        tooltip: 'CSVエクスポート',
                        onPressed: () => _exportCsv(uid),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: Colors.grey[100]),
                ],
              ),
            ),

            // ── カテゴリフィルタ ──
            _buildCategoryFilter(uid),

            // ── ガジェット一覧 ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final gadgets = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  }).toList();

                  if (_isSpreadsheetView) {
                    return _buildSpreadsheetView(gadgets);
                  }
                  return _buildCardView(gadgets);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GadgetRegisterScreen()),
          );
          if (result == true) setState(() {});
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery(String uid) {
    var query = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gadgets')
        .orderBy('createdAt', descending: true);

    if (_filterCategory != 'すべて') {
      query = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gadgets')
          .where('category', isEqualTo: _filterCategory)
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }

  Widget _buildCategoryFilter(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gadgetCategories')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        final categories = ['すべて', 'カテゴリなし'];
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['name'] != null) categories.add(data['name']);
          }
        }

        return Container(
          color: Colors.white,
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _filterCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: TextStyle(fontSize: 13)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filterCategory = cat),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── カード表示 ──
  Widget _buildCardView(List<Map<String, dynamic>> gadgets) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gadgets.length,
      itemBuilder: (context, index) {
        final g = gadgets[index];
        return _buildGadgetCard(g);
      },
    );
  }

  Widget _buildGadgetCard(Map<String, dynamic> g) {
    final imageUrl = g['imageUrl'] ?? '';
    final name = g['name'] ?? '名前なし';
    final category = g['category'] ?? 'カテゴリなし';
    final amazonUrl = g['amazonUrl'] ?? '';
    final rakutenUrl = g['rakutenUrl'] ?? '';
    final memo = g['memo'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => _editGadget(g),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 画像
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                      color: Colors.grey[50],
                    ),
                    child: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                              ),
                              errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, color: AppTheme.textHint),
                            ),
                          )
                        : const Icon(Icons.devices_other, size: 32, color: AppTheme.textHint),
                  ),
                  const SizedBox(width: 12),
                  // 情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (category != 'カテゴリなし')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(category,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        if (memo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(memo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  // 操作
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                    onSelected: (val) {
                      if (val == 'edit') _editGadget(g);
                      if (val == 'delete') _deleteGadget(g);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('編集')),
                      const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: AppTheme.error))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── Amazon / 楽天 ボタン ──
          if (amazonUrl.isNotEmpty || rakutenUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (amazonUrl.isNotEmpty)
                    Expanded(
                      child: _buildStoreButton(
                        label: 'Amazonで見る',
                        color: const Color(0xFFFF9900),
                        icon: Icons.shopping_cart,
                        onTap: () => _openAffiliateUrl(
                          AffiliateConfig.buildAmazonAffiliateUrl(amazonUrl),
                        ),
                      ),
                    ),
                  if (amazonUrl.isNotEmpty && rakutenUrl.isNotEmpty)
                    const SizedBox(width: 8),
                  if (rakutenUrl.isNotEmpty)
                    Expanded(
                      child: _buildStoreButton(
                        label: '楽天で見る',
                        color: const Color(0xFFBF0000),
                        icon: Icons.shopping_bag,
                        onTap: () => _openAffiliateUrl(
                          AffiliateConfig.buildRakutenAffiliateUrl(rakutenUrl),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAffiliateUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URLを開けませんでした'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── スプレッドシート表示 ──
  Widget _buildSpreadsheetView(List<Map<String, dynamic>> gadgets) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withValues(alpha: 0.08)),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('画像', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('商品名', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('Amazon URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('楽天 URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('メモ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ],
          rows: gadgets.map((g) {
            final imageUrl = g['imageUrl'] ?? '';
            return DataRow(cells: [
              DataCell(
                imageUrl.isNotEmpty
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
                      )
                    : const Icon(Icons.image_not_supported, size: 24, color: AppTheme.textHint),
              ),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(g['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
              DataCell(Text(g['category'] ?? 'カテゴリなし', style: const TextStyle(fontSize: 13))),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(g['amazonUrl'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFFF9900))),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(g['rakutenUrl'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFBF0000))),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(g['memo'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                    onPressed: () => _editGadget(g),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                    onPressed: () => _deleteGadget(g),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices_other, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('ガジェットがまだありません',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('右下の＋ボタンから登録できます',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GadgetRegisterScreen()),
              );
              if (result == true) setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('ガジェットを登録'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
          ),
        ],
      ),
    );
  }

  void _editGadget(Map<String, dynamic> g) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GadgetRegisterScreen(existingGadget: g)),
    );
    if (result == true) setState(() {});
  }

  void _deleteGadget(Map<String, dynamic> g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ガジェットを削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('「${g['name']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null && g['id'] != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('gadgets')
                    .doc(g['id'])
                    .delete();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              minimumSize: const Size(100, 40),
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gadgets')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('エクスポートするガジェットがありません'), backgroundColor: AppTheme.warning),
          );
        }
        return;
      }

      final rows = <List<String>>[
        ['商品名', 'カテゴリ', 'Amazon URL', '楽天 URL', '画像URL', 'メモ'],
      ];

      for (final doc in snapshot.docs) {
        final g = doc.data();
        rows.add([
          g['name'] ?? '',
          g['category'] ?? 'カテゴリなし',
          g['amazonUrl'] ?? '',
          g['rakutenUrl'] ?? '',
          g['imageUrl'] ?? '',
          g['memo'] ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(rows);
      downloadCsvFile(csvString, 'gadgets_export.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVをエクスポートしました'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}
