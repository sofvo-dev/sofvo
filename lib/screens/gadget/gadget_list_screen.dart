import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/amazon_search_service.dart';
import '../../config/app_theme.dart';
import 'gadget_register_screen.dart';

class GadgetListScreen extends StatefulWidget {
  const GadgetListScreen({super.key});

  @override
  State<GadgetListScreen> createState() => _GadgetListScreenState();
}

class _GadgetListScreenState extends State<GadgetListScreen> {
  String _filterCategory = 'すべて';
  bool _isGridView = false;
  String _userSearchId = '';
  List<String> _categories = ['すべて', 'カテゴリなし'];

  @override
  void initState() {
    super.initState();
    _loadUserSearchId();
  }

  Future<void> _loadUserSearchId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _userSearchId = (doc.data()?['searchId'] ?? '') as String;
      });
    }
  }

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
      appBar: AppBar(
        title: const Text('ガジェット管理'),
        actions: [
          // 表示切り替え（リスト / グリッド）
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Colors.white,
            ),
            tooltip: _isGridView ? 'リスト表示' : 'グリッド表示',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── カテゴリフィルタ（ドロップダウン） ──
          _buildCategoryFilter(uid),

          // ── ガジェット一覧 ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildEmptyState();
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }
                if (snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var gadgets = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();

                // カテゴリフィルタ適用（クライアント側）
                gadgets = _applyFilter(gadgets);
                if (gadgets.isEmpty) {
                  return _buildEmptyState();
                }

                // sortOrder順にソート
                gadgets.sort((a, b) {
                  final orderA = (a['sortOrder'] as num?) ?? 999999;
                  final orderB = (b['sortOrder'] as num?) ?? 999999;
                  return orderA.compareTo(orderB);
                });

                // sortOrder未設定の場合は初期化
                final hasMissing = gadgets.any((g) => g['sortOrder'] == null);
                if (hasMissing) {
                  _initSortOrders(gadgets);
                }

                if (_isGridView) {
                  return _buildGridView(gadgets);
                }
                return _buildCardView(gadgets);
              },
            ),
          ),
        ],
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

  Future<void> _onReorder(List<Map<String, dynamic>> gadgets, int oldIndex, int newIndex) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (oldIndex == newIndex) return;
    // ReorderableListViewの仕様: 下に移動する場合newIndexが1大きい
    if (newIndex > oldIndex) newIndex--;

    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('gadgets');
    final batch = FirebaseFirestore.instance.batch();

    // リスト内で移動を反映して全アイテムのsortOrderを再設定
    final item = gadgets.removeAt(oldIndex);
    gadgets.insert(newIndex, item);

    for (var i = 0; i < gadgets.length; i++) {
      batch.update(col.doc(gadgets[i]['id'] as String), {'sortOrder': i});
    }
    await batch.commit();
  }

  /// sortOrderが未設定のガジェットに初期値を一括設定
  Future<void> _initSortOrders(List<Map<String, dynamic>> gadgets) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('gadgets');
    final batch = FirebaseFirestore.instance.batch();
    var needsUpdate = false;

    for (var i = 0; i < gadgets.length; i++) {
      if (gadgets[i]['sortOrder'] == null) {
        batch.update(col.doc(gadgets[i]['id'] as String), {'sortOrder': i});
        gadgets[i]['sortOrder'] = i;
        needsUpdate = true;
      }
    }

    if (needsUpdate) await batch.commit();
  }

  Stream<QuerySnapshot> _buildQuery(String uid) {
    // orderByなし：sortOrderはクライアント側でソート、全ドキュメントを取得
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gadgets')
        .snapshots();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> gadgets) {
    if (_filterCategory == 'すべて') return gadgets;
    return gadgets.where((g) {
      final cat = (g['category'] ?? '') as String;
      if (_filterCategory == 'カテゴリなし') {
        return cat.isEmpty || cat == 'カテゴリなし';
      }
      return cat == _filterCategory;
    }).toList();
  }

  Widget _buildCategoryFilter(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('gadgetCategories')
          .orderBy('createdAt').snapshots(),
      builder: (context, catSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(uid).collection('gadgets')
              .snapshots(),
          builder: (context, gadgetSnapshot) {
            final categories = <String>['すべて', 'カテゴリなし'];
            final seen = <String>{'すべて', 'カテゴリなし'};

            // gadgetCategoriesコレクションから
            if (catSnapshot.hasData) {
              for (final doc in catSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] as String?;
                if (name != null && name.isNotEmpty && seen.add(name)) {
                  categories.add(name);
                }
              }
            }
            // gadgetドキュメントのcategoryフィールドから（未登録カテゴリを補完）
            if (gadgetSnapshot.hasData) {
              for (final doc in gadgetSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final cat = (data['category'] ?? '') as String;
                if (cat.isNotEmpty && cat != 'カテゴリなし' && seen.add(cat)) {
                  categories.add(cat);
                }
              }
            }
            _categories = categories;
            // 選択中のカテゴリが存在しない場合リセット
            if (!categories.contains(_filterCategory)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _filterCategory = 'すべて');
              });
            }

            return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: categories.contains(_filterCategory) ? _filterCategory : 'すべて',
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textSecondary),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                items: categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Row(children: [
                    Icon(
                      cat == 'すべて' ? Icons.all_inclusive
                          : cat == 'カテゴリなし' ? Icons.label_off_outlined
                          : Icons.label_outlined,
                      size: 16,
                      color: _filterCategory == cat ? AppTheme.primaryColor : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(cat, style: TextStyle(
                      fontWeight: _filterCategory == cat ? FontWeight.bold : FontWeight.normal,
                      color: _filterCategory == cat ? AppTheme.primaryColor : AppTheme.textPrimary,
                    )),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _filterCategory = v ?? 'すべて'),
              ),
            ),
          ),
            );
          },
        );
      },
    );
  }

  // ── リスト表示（長押しドラッグで並び替え） ──
  Widget _buildCardView(List<Map<String, dynamic>> gadgets) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gadgets.length,
      onReorder: (oldIndex, newIndex) => _onReorder(gadgets, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final g = gadgets[index];
        return _buildGadgetCard(g, key: ValueKey(g['id']));
      },
    );
  }

  Widget _buildGadgetCard(Map<String, dynamic> g, {Key? key}) {
    final imageUrl = g['imageUrl'] ?? '';
    final name = g['name'] ?? '名前なし';
    final category = g['category'] ?? 'カテゴリなし';
    final memo = g['memo'] ?? '';
    final amazonAffUrl = (g['amazonAffiliateUrl'] ?? '').toString();
    final rakutenAffUrl = (g['rakutenAffiliateUrl'] ?? '').toString();
    final hasAmazon = amazonAffUrl.isNotEmpty;
    final hasRakuten = rakutenAffUrl.isNotEmpty;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showGadgetDetail(g),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ドラッグハンドル
              Icon(Icons.drag_handle, size: 20, color: Colors.grey[350]),
              const SizedBox(width: 8),
              // 画像 + カテゴリ
              Column(
                children: [
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
                  if (category != 'カテゴリなし') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(category,
                          style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
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
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (hasAmazon)
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(amazonAffUrl), mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9900).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.shopping_cart, size: 11, color: Color(0xFFFF9900)),
                              SizedBox(width: 3),
                              Text('Amazon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF9900))),
                            ]),
                          ),
                        ),
                      if (hasRakuten)
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(rakutenAffUrl), mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBF0000).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.shopping_bag, size: 11, color: Color(0xFFBF0000)),
                              SizedBox(width: 3),
                              Text('楽天', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBF0000))),
                            ]),
                          ),
                        ),
                    ]),
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
    );
  }

  // ── グリッド表示 ──
  Widget _buildGridView(List<Map<String, dynamic>> gadgets) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: gadgets.length,
      itemBuilder: (context, index) => _buildGridCard(gadgets[index]),
    );
  }

  Widget _buildGridCard(Map<String, dynamic> g) {
    final imageUrl = g['imageUrl'] ?? '';
    final name = g['name'] ?? '名前なし';
    final category = g['category'] ?? 'カテゴリなし';
    final amazonAffUrl = (g['amazonAffiliateUrl'] ?? '').toString();
    final rakutenAffUrl = (g['rakutenAffiliateUrl'] ?? '').toString();
    final hasAmazon = amazonAffUrl.isNotEmpty;
    final hasRakuten = rakutenAffUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _showGadgetDetail(g),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey[50],
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported, color: AppTheme.textHint),
                          ),
                        ),
                      )
                    : const Center(child: Icon(Icons.devices_other, size: 36, color: AppTheme.textHint)),
              ),
            ),
            // 情報
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (category != 'カテゴリなし')
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (category != 'カテゴリなし' && (hasAmazon || hasRakuten))
                      const SizedBox(width: 4),
                    if (hasAmazon)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFFF9900), shape: BoxShape.circle),
                      ),
                    if (hasAmazon && hasRakuten) const SizedBox(width: 3),
                    if (hasRakuten)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Color(0xFFBF0000), shape: BoxShape.circle),
                      ),
                  ]),
                ],
              ),
            ),
          ],
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

  void _showGadgetDetail(Map<String, dynamic> g) {
    final name = g['name'] ?? '名前なし';
    final category = (g['category'] ?? '') as String;
    final imageUrl = (g['imageUrl'] ?? '') as String;
    final memo = (g['memo'] ?? '') as String;
    final amazonUrl = (g['amazonUrl'] ?? '').toString();
    final amazonAffUrl = (g['amazonAffiliateUrl'] ?? '').toString();
    final rakutenAffUrl = (g['rakutenAffiliateUrl'] ?? '').toString();
    final hasAmazon = amazonAffUrl.isNotEmpty;
    final hasRakuten = rakutenAffUrl.isNotEmpty;

    // Amazon ASINを抽出（価格取得用）
    final asin = amazonUrl.isNotEmpty
        ? AmazonSearchService.extractAsin(amazonUrl)
        : amazonAffUrl.isNotEmpty
            ? AmazonSearchService.extractAsin(amazonAffUrl)
            : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String? amazonPrice;
        bool priceLoading = asin != null;
        bool fetchStarted = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // 価格取得を1回だけ開始
            if (!fetchStarted && asin != null) {
              fetchStarted = true;
              AmazonSearchService.fetchPrice(asin).then((price) {
                if (ctx.mounted) {
                  setModalState(() {
                    amazonPrice = price;
                    priceLoading = false;
                  });
                }
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 200,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (_, __, ___) => const SizedBox(height: 200, child: Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey))),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Icon(Icons.devices_other, size: 48, color: Colors.grey)),
                    ),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  if (category.isNotEmpty && category != 'カテゴリなし') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(category, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (memo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(memo, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5), textAlign: TextAlign.center),
                  ],
                  // リアルタイム価格表示
                  if (hasAmazon) ...[
                    const SizedBox(height: 16),
                    if (priceLoading)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('価格を取得中...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      )
                    else if (amazonPrice != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.amazon, size: 14, color: Color(0xFFFF9900)),
                            const SizedBox(width: 8),
                            Text('現在の価格: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            Text(amazonPrice!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                          ],
                        ),
                      )
                    else
                      Text('価格を取得できませんでした', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                  const SizedBox(height: 16),
                  if (hasAmazon)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(amazonAffUrl), mode: LaunchMode.externalApplication),
                        icon: const FaIcon(FontAwesomeIcons.amazon, size: 18, color: Colors.white),
                        label: const Text('Amazonで見る', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9900),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (hasAmazon && hasRakuten) const SizedBox(height: 10),
                  if (hasRakuten)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(rakutenAffUrl), mode: LaunchMode.externalApplication),
                        icon: const Text('R', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontStyle: FontStyle.italic)),
                        label: const Text('楽天で見る', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBF0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (!hasAmazon && !hasRakuten)
                    Text('購入リンクは登録されていません', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () { Navigator.pop(ctx); _editGadget(g); },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('編集する', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

}
