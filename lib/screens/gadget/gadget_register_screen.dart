import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../services/amazon_search_service.dart';

class GadgetRegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? existingGadget;
  const GadgetRegisterScreen({super.key, this.existingGadget});

  @override
  State<GadgetRegisterScreen> createState() => _GadgetRegisterScreenState();
}

class _GadgetRegisterScreenState extends State<GadgetRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _amazonUrlCtrl = TextEditingController();
  final _rakutenUrlCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedCategory = 'カテゴリなし';
  bool _isSaving = false;
  bool _isSearching = false;
  bool _isFetchingUrl = false;
  List<AmazonProduct> _searchResults = [];
  String? _editingId;

  @override
  void initState() {
    super.initState();
    if (widget.existingGadget != null) {
      final g = widget.existingGadget!;
      _editingId = g['id'];
      _nameCtrl.text = g['name'] ?? '';
      _amazonUrlCtrl.text = g['amazonUrl'] ?? '';
      _rakutenUrlCtrl.text = g['rakutenUrl'] ?? '';
      _imageUrlCtrl.text = g['imageUrl'] ?? '';
      _memoCtrl.text = g['memo'] ?? '';
      _selectedCategory = g['category'] ?? 'カテゴリなし';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amazonUrlCtrl.dispose();
    _rakutenUrlCtrl.dispose();
    _imageUrlCtrl.dispose();
    _memoCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _showEmptyHint = false;

  Future<void> _searchAmazon() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _showEmptyHint = false;
    });
    try {
      final results = await AmazonSearchService.searchProducts(
        _searchCtrl.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _showEmptyHint = results.isEmpty;
      });
    } catch (_) {
      setState(() => _showEmptyHint = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('検索に失敗しました'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _openAmazonSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    final url = Uri.parse(
        'https://www.amazon.co.jp/s?k=${Uri.encodeComponent(keyword)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _selectProduct(AmazonProduct product) {
    setState(() {
      _nameCtrl.text = product.title;
      _imageUrlCtrl.text = product.imageUrl;
      _amazonUrlCtrl.text = product.detailPageUrl;
      _searchResults = [];
      _searchCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('商品情報を自動入力しました'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchFromAmazonUrl() async {
    final url = _amazonUrlCtrl.text.trim();
    if (url.isEmpty) return;

    if (!url.contains('amazon')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amazon URLを入力してください'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isFetchingUrl = true);
    try {
      final product = await AmazonSearchService.fetchProductByUrl(url);
      if (product != null) {
        setState(() {
          if (product.title.isNotEmpty) _nameCtrl.text = product.title;
          if (product.imageUrl.isNotEmpty) _imageUrlCtrl.text = product.imageUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(product.title.isNotEmpty
                  ? '商品情報を取得しました'
                  : '画像URLを取得しました（商品名は手動入力してください）'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('商品情報を取得できませんでした'),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('取得に失敗しました'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isFetchingUrl = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名を入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final gadgetData = {
        'name': _nameCtrl.text.trim(),
        'amazonUrl': _amazonUrlCtrl.text.trim(),
        'rakutenUrl': _rakutenUrlCtrl.text.trim(),
        'imageUrl': _imageUrlCtrl.text.trim(),
        'memo': _memoCtrl.text.trim(),
        'category': _selectedCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('gadgets');

      if (_editingId != null) {
        await collection.doc(_editingId).update(gadgetData);
      } else {
        gadgetData['createdAt'] = FieldValue.serverTimestamp();
        final doc = await collection.add(gadgetData);
        await doc.update({'id': doc.id});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingId != null ? 'ガジェットを更新しました' : 'ガジェットを登録しました'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCategoryDialog() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CategoryPickerSheet(
        uid: uid,
        selected: _selectedCategory,
        onSelected: (cat) {
          setState(() => _selectedCategory = cat);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_editingId != null ? 'ガジェット編集' : 'ガジェット登録'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Amazon検索 ──
          _buildSectionLabel('Amazon商品検索'),
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
                Row(
                  children: [
                    Icon(Icons.search, color: const Color(0xFFFF9900), size: 20),
                    const SizedBox(width: 8),
                    const Text('キーワードで検索',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: '商品名を入力...',
                          hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2),
                          ),
                        ),
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
                  ],
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  ...(_searchResults.map((p) => _buildSearchResultTile(p))),
                ],
                if (_showEmptyHint) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '商品が見つかりませんでした',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openAmazonSearch,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Amazonで検索して\nURLを貼り付け',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF9900),
                            side: const BorderSide(color: Color(0xFFFF9900)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── プレビュー（画像がある場合） ──
          if (_imageUrlCtrl.text.isNotEmpty) ...[
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrlCtrl.text,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: AppTheme.textHint),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 商品名 ──
          _buildSectionLabel('商品名 *'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            maxLength: 100,
            decoration: _inputDecoration('商品名を入力'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // ── カテゴリ ──
          _buildSectionLabel('カテゴリ'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCategoryDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedCategory == 'カテゴリなし' ? Icons.label_off_outlined : Icons.label_outlined,
                    color: _selectedCategory == 'カテゴリなし' ? AppTheme.textHint : AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCategory,
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedCategory == 'カテゴリなし' ? AppTheme.textHint : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Amazon URL ──
          _buildSectionLabel('Amazon URL（アフィリエイト）'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amazonUrlCtrl,
                  decoration: _inputDecoration('https://www.amazon.co.jp/...'),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isFetchingUrl ? null : _fetchFromAmazonUrl,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(56, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFFF9900)),
                    foregroundColor: const Color(0xFFFF9900),
                  ),
                  child: _isFetchingUrl
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9900)))
                      : const Text('取得', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('URLを貼り付けて「取得」で画像・商品名を自動入力',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),

          // ── 楽天 URL ──
          _buildSectionLabel('楽天 URL（アフィリエイト）'),
          const SizedBox(height: 8),
          TextField(
            controller: _rakutenUrlCtrl,
            decoration: _inputDecoration('https://item.rakuten.co.jp/...'),
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text('スプレッドシートで一括管理も可能です',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),

          // ── 画像URL ──
          _buildSectionLabel('画像URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _imageUrlCtrl,
            decoration: _inputDecoration('https://...'),
            maxLines: 1,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // ── メモ ──
          _buildSectionLabel('メモ'),
          const SizedBox(height: 8),
          TextField(
            controller: _memoCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: _inputDecoration('メモを入力').copyWith(alignLabelWithHint: true),
          ),
          const SizedBox(height: 24),

          // ── 保存ボタン ──
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_editingId != null ? '更新する' : '登録する',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
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
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  if (product.price != null)
                    Text(product.price!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error)),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: Color(0xFFFF9900), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// カテゴリ選択・新規作成シート
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _CategoryPickerSheet extends StatefulWidget {
  final String uid;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryPickerSheet({
    required this.uid,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _newCategoryCtrl = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('gadgetCategories')
          .add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _newCategoryCtrl.clear();
      setState(() => _isAdding = false);
    } catch (e) {
      setState(() => _isAdding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deleteCategory(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('gadgetCategories')
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('カテゴリを選択',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ),
              const SizedBox(height: 12),

              // ── 新規作成 ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryCtrl,
                        decoration: InputDecoration(
                          hintText: '新しいカテゴリ名',
                          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _addCategory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isAdding ? null : _addCategory,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(56, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isAdding
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),

              // ── カテゴリ一覧 ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.uid)
                      .collection('gadgetCategories')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final categories = <Map<String, dynamic>>[
                      {'id': '__none__', 'name': 'カテゴリなし'},
                    ];

                    if (snapshot.hasData) {
                      for (final doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        categories.add({'id': doc.id, 'name': data['name'] ?? ''});
                      }
                    }

                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final name = cat['name'] as String;
                        final isSelected = name == widget.selected;
                        final isDefault = cat['id'] == '__none__';

                        return ListTile(
                          leading: Icon(
                            isDefault ? Icons.label_off_outlined : Icons.label_outlined,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                            ),
                          ),
                          trailing: isDefault
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                  onPressed: () => _deleteCategory(cat['id']),
                                ),
                          selected: isSelected,
                          onTap: () => widget.onSelected(name),
                        );
                      },
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
}
