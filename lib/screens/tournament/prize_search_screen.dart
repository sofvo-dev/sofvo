import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/amazon_search_service.dart';

class PrizeSearchScreen extends StatefulWidget {
  const PrizeSearchScreen({super.key});
  @override
  State<PrizeSearchScreen> createState() => _PrizeSearchScreenState();
}

class _PrizeSearchScreenState extends State<PrizeSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterCategory = 'すべて';
  String _sortBy = 'name'; // 'name', 'category', 'price', 'rating'

  static const _categories = [
    'スポーツ用品',
    'ギフトカード',
    '食品・飲料',
    '日用品',
    'その他',
  ];

  static const _priceRanges = [
    '~500円',
    '~1,000円',
    '~3,000円',
    '~5,000円',
    '~10,000円',
    '10,000円~',
  ];

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('景品をさがす', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              final result = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const PrizeRegisterScreen()));
              if (result == true) setState(() {});
            }),
        ],
      ),
      body: Column(children: [
        // 検索窓 + カテゴリフィルタ（横並び）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '景品名で検索',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true, fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('prizeCategories').orderBy('createdAt').snapshots(),
              builder: (context, catSnapshot) {
                final customCats = <String>[];
                if (catSnapshot.hasData) {
                  final presetSet = <String>{..._categories};
                  for (final doc in catSnapshot.data!.docs) {
                    final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
                    if (name.toString().isNotEmpty && !presetSet.contains(name)) {
                      customCats.add(name.toString());
                    }
                  }
                }
                final allCats = ['すべて', ..._categories, ...customCats];
                // フィルタ値がリストにない場合はリセット
                if (!allCats.contains(_filterCategory)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _filterCategory = 'すべて');
                  });
                }
                return Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: allCats.contains(_filterCategory) ? _filterCategory : 'すべて',
                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondary),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      items: allCats.map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat)),
                      ).toList(),
                      onChanged: (v) => setState(() => _filterCategory = v ?? 'すべて'),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
        // 並び替え
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.sort, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text('並び替え:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            _buildSortChip('景品名', 'name'),
            const SizedBox(width: 6),
            _buildSortChip('カテゴリ', 'category'),
            const SizedBox(width: 6),
            _buildSortChip('価格帯', 'price'),
            const SizedBox(width: 6),
            _buildSortChip('評価', 'rating'),
          ]),
        ),
        const SizedBox(height: 8),
        // 案内
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '大会で使える景品アイデアを共有しましょう！よかった景品があれば登録してください。',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('prizes').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                if (_query.isNotEmpty && !name.contains(_query)) return false;
                if (_filterCategory != 'すべて' && data['category'] != _filterCategory) return false;
                return true;
              }).toList();
              // ソート
              filtered.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;
                switch (_sortBy) {
                  case 'category':
                    return (da['category'] ?? '').toString().compareTo((db['category'] ?? '').toString());
                  case 'price':
                    return _priceRanges.indexOf(da['priceRange'] ?? '')
                        .compareTo(_priceRanges.indexOf(db['priceRange'] ?? ''));
                  case 'rating':
                    final ra = (da['rating'] is num ? (da['rating'] as num).toDouble() : 0.0);
                    final rb = (db['rating'] is num ? (db['rating'] as num).toDouble() : 0.0);
                    return rb.compareTo(ra); // 高評価順
                  default:
                    return (da['name'] ?? '').toString().compareTo((db['name'] ?? '').toString());
                }
              });
              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.card_giftcard, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('景品が見つかりません', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => const PrizeRegisterScreen()));
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('景品を登録する'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  ),
                ]));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final data = filtered[index].data() as Map<String, dynamic>;
                  return _buildPrizeCard(data, filtered[index].id);
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildPrizeCard(Map<String, dynamic> data, String docId) {
    final name = data['name'] ?? '';
    final category = data['category'] ?? '';
    final priceRange = data['priceRange'] ?? '';
    final url = data['amazonAffiliateUrl'] ?? data['url'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final memo = data['memo'] ?? '';
    final rating = (data['rating'] is num ? (data['rating'] as num).toDouble() : 0.0);
    final reviewCount = (data['reviewCount'] is num ? (data['reviewCount'] as num).toInt() : 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPrizeDetail(data, docId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サムネイル
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl, width: 56, height: 56, fit: BoxFit.contain,
                    placeholder: (_, __) => _placeholderImage(),
                    errorWidget: (_, __, ___) => _placeholderImage(),
                  ),
                )
              else
                _placeholderImage(),
              const SizedBox(width: 12),
              // テキスト情報
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                    if (rating > 0) ...[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(' ${rating.toStringAsFixed(1)} ($reviewCount)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => PrizeRegisterScreen(
                            existingPrize: data, prizeId: docId)));
                        if (result == true) setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryColor),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    if (category.isNotEmpty) _tag(category, AppTheme.primaryColor),
                    if (priceRange.isNotEmpty) _tag(priceRange, Colors.orange),
                  ]),
                  if (memo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(memo, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                  if (url.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.link, size: 12, color: AppTheme.primaryColor),
                      const SizedBox(width: 2),
                      Text('購入先リンクあり', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                    ]),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.card_giftcard, size: 28, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _showPrizeDetail(Map<String, dynamic> data, String docId) {
    final name = data['name'] ?? '';
    final category = data['category'] ?? '';
    final priceRange = data['priceRange'] ?? '';
    final amazonAffiliateUrl = (data['amazonAffiliateUrl'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final memo = (data['memo'] ?? '').toString();
    final rating = (data['rating'] is num ? (data['rating'] as num).toDouble() : 0.0);
    final reviewCount = (data['reviewCount'] is num ? (data['reviewCount'] as num).toInt() : 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 画像
                  if (imageUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl, height: 180, fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (imageUrl.isNotEmpty) const SizedBox(height: 16),

                  // 景品名
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // 評価サマリー
                  if (rating > 0)
                    Row(children: [
                      ...List.generate(5, (i) => Icon(
                        i < rating.round() ? Icons.star : Icons.star_border,
                        size: 20, color: Colors.amber,
                      )),
                      const SizedBox(width: 8),
                      Text('${rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(width: 4),
                      Text('($reviewCount件のレビュー)',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ]),
                  const SizedBox(height: 12),

                  // タグ
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (category.isNotEmpty) _detailTag(Icons.category, category, AppTheme.primaryColor),
                    if (priceRange.isNotEmpty) _detailTag(Icons.payments_outlined, priceRange, Colors.orange),
                  ]),
                  const SizedBox(height: 16),

                  // メモ
                  if (memo.isNotEmpty) ...[
                    const Text('メモ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(memo, style: const TextStyle(fontSize: 14, height: 1.5)),
                    const SizedBox(height: 16),
                  ],

                  // レビュー・口コミセクション
                  Row(children: [
                    const Text('レビュー・口コミ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddReviewSheet(docId, name);
                      },
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text('レビューを書く', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // レビュー一覧（StreamBuilder）
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('prizes').doc(docId)
                        .collection('reviews')
                        .orderBy('createdAt', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, reviewSnapshot) {
                      if (!reviewSnapshot.hasData) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ));
                      }
                      final reviews = reviewSnapshot.data!.docs;
                      if (reviews.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            Icon(Icons.rate_review_outlined, size: 32, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            const Text('まだレビューがありません',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            const Text('この景品を使ったことがあればレビューを書きましょう！',
                              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                          ]),
                        );
                      }
                      return Column(
                        children: reviews.map((doc) {
                          final r = doc.data() as Map<String, dynamic>;
                          return _buildReviewTile(r);
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 購入先リンク
                  if (amazonAffiliateUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final uri = Uri.tryParse(amazonAffiliateUrl);
                          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('購入先を開く'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 編集ボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => PrizeRegisterScreen(existingPrize: data, prizeId: docId)));
                        if (result == true) setState(() {});
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('この景品の情報を編集する'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> review) {
    final reviewRating = (review['rating'] is num ? (review['rating'] as num).toInt() : 0);
    final comment = (review['comment'] ?? '').toString();
    final createdAt = review['createdAt'];
    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr = '${dt.year}/${dt.month}/${dt.day}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ...List.generate(5, (i) => Icon(
            i < reviewRating ? Icons.star : Icons.star_border,
            size: 16, color: Colors.amber,
          )),
          const Spacer(),
          if (dateStr.isNotEmpty)
            Text(dateStr, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment, style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textPrimary)),
        ],
      ]),
    );
  }

  void _showAddReviewSheet(String prizeId, String prizeName) {
    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('レビューを書く', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(prizeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),

                // 星評価
                const Text('評価', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < selectedRating ? Icons.star : Icons.star_border,
                        size: 36, color: Colors.amber,
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 16),

                // コメント
                const Text('コメント', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '例: 参加者にとても喜ばれました！コスパも良いです。',
                    hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                    filled: true, fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),

                // 送信ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedRating > 0 && !isSaving) ? () async {
                      setSheetState(() => isSaving = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        // レビューを追加
                        await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .collection('reviews')
                            .add({
                          'rating': selectedRating,
                          'comment': commentCtrl.text.trim(),
                          'userId': user?.uid ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // 景品の平均評価とレビュー数を更新
                        final reviewsSnap = await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .collection('reviews')
                            .get();
                        double totalRating = 0;
                        for (final doc in reviewsSnap.docs) {
                          final r = doc.data();
                          totalRating += (r['rating'] is num ? (r['rating'] as num).toDouble() : 0);
                        }
                        final avgRating = reviewsSnap.docs.isNotEmpty
                            ? totalRating / reviewsSnap.docs.length
                            : 0.0;
                        await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .update({
                          'rating': double.parse(avgRating.toStringAsFixed(1)),
                          'reviewCount': reviewsSnap.docs.length,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('レビューを投稿しました！'), backgroundColor: AppTheme.success),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setSheetState(() => isSaving = false);
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('レビューを投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _detailTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 景品登録・編集画面（Amazon検索で選択）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PrizeRegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPrize;
  final String? prizeId;
  const PrizeRegisterScreen({super.key, this.existingPrize, this.prizeId});
  @override
  State<PrizeRegisterScreen> createState() => _PrizeRegisterScreenState();
}

class _PrizeRegisterScreenState extends State<PrizeRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _nameFieldKey = GlobalKey();

  // Amazon連携
  String _asin = '';
  String _amazonUrl = '';
  String _amazonAffiliateUrl = '';
  String _imageUrl = '';

  String _category = 'スポーツ用品';
  String _priceRange = '~1,000円';

  bool _saving = false;
  bool _isSearching = false;
  bool _isFetchingUrl = false;
  bool _isLoadingMore = false;
  List<AmazonProduct> _searchResults = [];
  Map<String, String> _fetchedPrices = {}; // ASIN -> price
  int _searchPage = 1;
  bool _hasMoreResults = false;
  String _lastSearchKeyword = '';
  bool _showEmptyHint = false;

  bool get _isEditing => widget.prizeId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingPrize != null) {
      final p = widget.existingPrize!;
      _nameCtrl.text = (p['name'] as String?) ?? '';
      _category = (p['category'] as String?) ?? 'スポーツ用品';
      _priceRange = (p['priceRange'] as String?) ?? '~1,000円';
      _asin = (p['asin'] as String?) ?? '';
      _amazonUrl = (p['amazonUrl'] as String?) ?? '';
      _amazonAffiliateUrl = (p['amazonAffiliateUrl'] as String?) ?? '';
      _imageUrl = (p['imageUrl'] as String?) ?? '';
      _memoCtrl.text = (p['memo'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _searchAmazon() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _fetchedPrices = {};
      _searchPage = 1;
      _hasMoreResults = false;
      _lastSearchKeyword = keyword;
      _showEmptyHint = false;
    });
    try {
      final results = await AmazonSearchService.searchProducts(keyword);
      setState(() {
        _searchResults = results;
        _hasMoreResults = results.length >= 10;
        _showEmptyHint = results.isEmpty;
      });
      // 価格が無い商品の価格を非同期で取得
      _fetchMissingPrices(results);
    } catch (_) {
      setState(() => _showEmptyHint = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('検索に失敗しました。キーワードを変えてお試しください。'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _fetchMissingPrices(List<AmazonProduct> products) async {
    final targets = products.where((p) => p.price == null && p.asin.isNotEmpty).toList();
    if (targets.isEmpty) return;
    // 並列で最大5件ずつ取得
    for (var i = 0; i < targets.length; i += 5) {
      final batch = targets.skip(i).take(5);
      await Future.wait(batch.map((p) async {
        try {
          final price = await AmazonSearchService.fetchPrice(p.asin);
          if (price != null && mounted) {
            setState(() => _fetchedPrices[p.asin] = price);
          }
        } catch (_) {}
      }));
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMoreResults) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _searchPage + 1;
      final results = await AmazonSearchService.searchProducts(_lastSearchKeyword, page: nextPage);
      setState(() {
        _searchPage = nextPage;
        _searchResults.addAll(results);
        _hasMoreResults = results.length >= 10;
      });
      _fetchMissingPrices(results);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('追加読み込みに失敗しました'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _fetchByUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final asin = AmazonSearchService.extractAsin(url);
    if (asin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効なAmazon商品URLを入力してください'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }
    setState(() => _isFetchingUrl = true);
    try {
      final product = await AmazonSearchService.fetchProductByUrl(url);
      if (product != null) {
        setState(() {
          if (product.title.isNotEmpty) _nameCtrl.text = product.title;
          _asin = product.asin;
          _imageUrl = product.imageUrl;
          _amazonUrl = product.detailPageUrl;
          _amazonAffiliateUrl = product.affiliateUrl;
          _urlCtrl.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(product.title.isNotEmpty ? '商品情報を自動入力しました' : 'URLを登録しました。商品名を手動で入力してください。'),
              backgroundColor: product.title.isNotEmpty ? AppTheme.success : AppTheme.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('商品情報の取得に失敗しました。商品名を手動で入力してください。'), backgroundColor: AppTheme.warning),
        );
      }
    } finally {
      setState(() => _isFetchingUrl = false);
    }
  }

  void _scrollToNameField() {
    final ctx = _nameFieldKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _openAmazonSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    final url = Uri.parse('https://www.amazon.co.jp/s?k=${Uri.encodeComponent(keyword)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _selectProduct(AmazonProduct product) {
    setState(() {
      _nameCtrl.text = product.title;
      _asin = product.asin;
      _imageUrl = product.imageUrl;
      _amazonUrl = product.detailPageUrl;
      _amazonAffiliateUrl = product.affiliateUrl;
      _searchResults = [];
      _searchCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('商品情報を自動入力しました'), backgroundColor: AppTheme.success, duration: Duration(seconds: 2)),
    );
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PrizeCategoryPickerSheet(
        selected: _category,
        onSelected: (cat) {
          setState(() => _category = cat);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _savePrize() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('景品名を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prizeData = {
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'priceRange': _priceRange,
        'asin': _asin,
        'amazonUrl': _amazonUrl,
        'amazonAffiliateUrl': _amazonAffiliateUrl,
        'imageUrl': _imageUrl,
        'memo': _memoCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': user?.uid ?? '',
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('prizes')
            .doc(widget.prizeId)
            .update(prizeData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('景品情報を更新しました！'), backgroundColor: AppTheme.success));
          Navigator.pop(context, true);
        }
      } else {
        // 重複チェック: ASIN または景品名で既存を検索
        final name = _nameCtrl.text.trim();
        QuerySnapshot? dupCheck;
        if (_asin.isNotEmpty) {
          dupCheck = await FirebaseFirestore.instance
              .collection('prizes')
              .where('asin', isEqualTo: _asin)
              .limit(1)
              .get();
        }
        if (dupCheck == null || dupCheck.docs.isEmpty) {
          dupCheck = await FirebaseFirestore.instance
              .collection('prizes')
              .where('name', isEqualTo: name)
              .limit(1)
              .get();
        }
        if (dupCheck.docs.isNotEmpty && mounted) {
          final existingDoc = dupCheck.docs.first;
          final existingData = existingDoc.data() as Map<String, dynamic>;
          // 重複時: レビュー追加 or 新規登録 or キャンセル
          final action = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('同じ景品が登録済みです'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('「${existingData['name'] ?? name}」はすでに登録されています。',
                  style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                const Text('レビューを追加して、この景品の感想を共有しませんか？',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('キャンセル')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'register'), child: const Text('それでも登録')),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'review'),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('レビューを書く'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
          if (action == 'review' && mounted) {
            setState(() => _saving = false);
            Navigator.pop(context); // 登録画面を閉じる
            // 呼び出し元の一覧画面でレビューシートを表示するためにコールバック
            // ここではNavigator.popの結果としてレビュー情報を返す
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDuplicateReviewSheet(existingDoc.id, existingData['name'] ?? name);
            });
            return;
          }
          if (action != 'register') {
            setState(() => _saving = false);
            return;
          }
        }

        prizeData['registeredBy'] = user?.uid ?? '';
        prizeData['createdAt'] = FieldValue.serverTimestamp();
        prizeData['rating'] = 0;
        prizeData['reviewCount'] = 0;
        await FirebaseFirestore.instance.collection('prizes').add(prizeData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('景品を登録しました！'), backgroundColor: AppTheme.success));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showDuplicateReviewSheet(String prizeId, String prizeName) {
    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('レビューを書く', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(prizeName, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),

                const Text('評価', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < selectedRating ? Icons.star : Icons.star_border,
                        size: 36, color: Colors.amber,
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 16),

                const Text('コメント', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: '例: 参加者にとても喜ばれました！コスパも良いです。',
                    hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                    filled: true, fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedRating > 0 && !isSaving) ? () async {
                      setSheetState(() => isSaving = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .collection('reviews')
                            .add({
                          'rating': selectedRating,
                          'comment': commentCtrl.text.trim(),
                          'userId': user?.uid ?? '',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // 平均評価を再計算
                        final reviewsSnap = await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .collection('reviews')
                            .get();
                        double totalRating = 0;
                        for (final doc in reviewsSnap.docs) {
                          final r = doc.data();
                          totalRating += (r['rating'] is num ? (r['rating'] as num).toDouble() : 0);
                        }
                        final avgRating = reviewsSnap.docs.isNotEmpty
                            ? totalRating / reviewsSnap.docs.length
                            : 0.0;
                        await FirebaseFirestore.instance
                            .collection('prizes').doc(prizeId)
                            .update({
                          'rating': double.parse(avgRating.toStringAsFixed(1)),
                          'reviewCount': reviewsSnap.docs.length,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('レビューを投稿しました！'), backgroundColor: AppTheme.success),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setSheetState(() => isSaving = false);
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('レビューを投稿する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? '景品を編集' : '景品を登録',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
        actions: [
          TextButton(
            onPressed: canSave && !_saving ? _savePrize : null,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // ── Amazon検索 ──
          _buildSectionLabel('商品を検索'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.search, color: const Color(0xFFFF9900), size: 20),
                  const SizedBox(width: 8),
                  const Text('キーワードで検索',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ]),
                const SizedBox(height: 4),
                Text('景品名やブランド名で検索できます',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '例: ソフトバレーボール 景品',
                        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                        filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2)),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAmazon(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchAmazon,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9900),
                        minimumSize: const Size(56, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSearching
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                ]),
                // 検索結果
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  Text('${_searchResults.length}件見つかりました',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('タップして商品を選択してください',
                      style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                  const SizedBox(height: 4),
                  ...(_searchResults.map((p) => _buildSearchResultTile(p))),
                  if (_hasMoreResults) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoadingMore ? null : _loadMoreResults,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF9900),
                          side: const BorderSide(color: Color(0xFFFF9900)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoadingMore
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9900)))
                            : const Text('さらに読み込む', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
                // 検索結果なし
                if (_showEmptyHint) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('商品が見つかりませんでした。\n以下の方法で登録できます：',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  // Amazon URL貼り付け
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('① Amazon URLを貼り付け',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Amazonで商品を見つけて、URLをコピー＆ペースト',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            decoration: InputDecoration(
                              hintText: 'https://www.amazon.co.jp/dp/...',
                              hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                              filled: true, fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2)),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onSubmitted: (_) => _fetchByUrl(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: _isFetchingUrl ? null : _fetchByUrl,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9900),
                              minimumSize: const Size(56, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: _isFetchingUrl
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('取得', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openAmazonSearch,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Amazonで商品を探す', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9900),
                      side: const BorderSide(color: Color(0xFFFF9900)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _scrollToNameField,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('手動で景品名を入力する', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── プレビュー（画像がある場合） ──
          if (_imageUrl.isNotEmpty) ...[
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrl, fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: AppTheme.textHint),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 景品名 ──
          _buildSectionLabel('景品名 *', key: _nameFieldKey),
          const SizedBox(height: 4),
          Text('検索から自動入力されますが、手動で変更もできます',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco('景品名を入力'),
          ),
          const SizedBox(height: 8),

          // ── カテゴリ ──
          _buildSectionLabel('カテゴリ'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCategoryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.label, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_category, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('タップして変更', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── 価格帯 ──
          _buildSectionLabel('価格帯'),
          const SizedBox(height: 8),
          _dropdownField(
            value: _priceRange,
            items: _PrizeSearchScreenState._priceRanges,
            onChanged: (v) => setState(() => _priceRange = v ?? _priceRange),
          ),
          const SizedBox(height: 16),

          // ── メモ ──
          _buildSectionLabel('メモ'),
          const SizedBox(height: 8),
          TextField(
            controller: _memoCtrl,
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco('例: 20人規模の大会で使用。参加者に好評でした。'),
          ),
          const SizedBox(height: 24),

          // ── 保存ボタン ──
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: canSave && !_saving ? _savePrize : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_isEditing ? '景品を更新する' : '景品を登録する',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(AmazonProduct product) {
    return InkWell(
      onTap: () => _selectProduct(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl, fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
          const Icon(Icons.add_circle_outline, color: Color(0xFFFF9900), size: 22),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String text, {Key? key}) {
    return Text(text, key: key,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
    );
  }

  Widget _dropdownField({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          items: items.map((item) =>
            DropdownMenuItem(value: item, child: Text(item)),
          ).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 景品カテゴリ選択・新規作成シート
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _PrizeCategoryPickerSheet extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _PrizeCategoryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_PrizeCategoryPickerSheet> createState() => _PrizeCategoryPickerSheetState();
}

class _PrizeCategoryPickerSheetState extends State<_PrizeCategoryPickerSheet> {
  final _newCategoryCtrl = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCustomCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await FirebaseFirestore.instance
          .collection('prizeCategories')
          .add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _newCategoryCtrl.clear();
      if (mounted) widget.onSelected(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteCategory(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('prizeCategories')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('カテゴリを選択', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('prizeCategories')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final presetSet = <String>{..._PrizeSearchScreenState._categories};
                    final customCategories = <Map<String, dynamic>>[];
                    if (snapshot.hasData) {
                      for (final doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? '';
                        if (!presetSet.contains(name)) {
                          customCategories.add({'id': doc.id, 'name': name});
                        }
                      }
                    }

                    return ListView(
                      controller: scrollCtrl,
                      padding: EdgeInsets.zero,
                      children: [
                        // プリセットカテゴリ
                        ..._PrizeSearchScreenState._categories.map((name) => _buildCategoryTile(name)),

                        // ユーザー追加カテゴリ
                        if (customCategories.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildSectionHeader('追加されたカテゴリ'),
                          ...customCategories.map((cat) {
                            return _buildCategoryTile(
                              cat['name'] as String,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                onPressed: () => _deleteCategory(cat['id']),
                              ),
                            );
                          }),
                        ],

                        // カスタム作成
                        const Divider(height: 24),
                        _buildSectionHeader('カテゴリが見つからない場合'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _newCategoryCtrl,
                                decoration: InputDecoration(
                                  hintText: 'カテゴリ名を入力',
                                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                                  filled: true, fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                                ),
                                onSubmitted: (_) => _addCustomCategory(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isAdding ? null : _addCustomCategory,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(56, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isAdding
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('作成', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTile(String name, {Widget? trailing}) {
    final isSelected = name == widget.selected;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? AppTheme.primaryColor : Colors.grey[350],
        size: 22,
      ),
      title: Text(name, style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
      )),
      trailing: trailing,
      dense: true,
      onTap: () => widget.onSelected(name),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}
