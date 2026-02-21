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
  final _memoCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _nameFieldKey = GlobalKey();

  // 内部管理用
  String _amazonUrl = '';
  String _amazonAffiliateUrl = '';
  String _imageUrl = '';
  final _rakutenAffiliateCtrl = TextEditingController();

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
      _amazonUrl = g['amazonUrl'] ?? '';
      _amazonAffiliateUrl = g['amazonAffiliateUrl'] ?? '';
      _imageUrl = g['imageUrl'] ?? '';
      _rakutenAffiliateCtrl.text = g['rakutenAffiliateUrl'] ?? '';
      _memoCtrl.text = g['memo'] ?? '';
      _selectedCategory = g['category'] ?? 'カテゴリなし';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    _scrollController.dispose();
    _rakutenAffiliateCtrl.dispose();
    super.dispose();
  }

  bool _showEmptyHint = false;

  Future<void> _searchAmazon() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _showEmptyHint = false;
    });
    try {
      final results = await AmazonSearchService.searchProducts(keyword);
      setState(() {
        _searchResults = results;
        _showEmptyHint = results.isEmpty;
      });
    } catch (_) {
      setState(() => _showEmptyHint = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('検索に失敗しました。キーワードを変えてお試しください。'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// Amazon URLから商品情報を取得して自動入力
  Future<void> _fetchByUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    // ASIN抽出チェック
    final asin = AmazonSearchService.extractAsin(url);
    if (asin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('有効なAmazon商品URLを入力してください'),
            backgroundColor: AppTheme.warning,
          ),
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
          _imageUrl = product.imageUrl;
          _amazonUrl = product.detailPageUrl;
          _amazonAffiliateUrl = product.affiliateUrl;
          _urlCtrl.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(product.title.isNotEmpty
                  ? '商品情報を自動入力しました'
                  : 'URLを登録しました。商品名を手動で入力してください。'),
              backgroundColor: product.title.isNotEmpty ? AppTheme.success : AppTheme.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('商品情報の取得に失敗しました。商品名を手動で入力してください。'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } finally {
      setState(() => _isFetchingUrl = false);
    }
  }

  /// 商品名フィールドまでスクロールしてフォーカス
  void _scrollToNameField() {
    final ctx = _nameFieldKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
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
      _imageUrl = product.imageUrl;
      _amazonUrl = product.detailPageUrl;
      _amazonAffiliateUrl = product.affiliateUrl;
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
        'amazonUrl': _amazonUrl,
        'amazonAffiliateUrl': _amazonAffiliateUrl,
        'rakutenAffiliateUrl': _rakutenAffiliateCtrl.text.trim(),
        'imageUrl': _imageUrl,
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
                Row(
                  children: [
                    Icon(Icons.search, color: const Color(0xFFFF9900), size: 20),
                    const SizedBox(width: 8),
                    const Text('キーワードで検索',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('商品名やブランド名で検索できます',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: '例: ミカサ バレーボール',
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
                    '商品が見つかりませんでした。\n以下の方法で登録できます：',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  // 方法1: Amazon URLを貼り付け
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('① Amazon URLを貼り付け',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Amazonで商品を見つけて、URLをコピー＆ペースト',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlCtrl,
                                decoration: InputDecoration(
                                  hintText: 'https://www.amazon.co.jp/dp/...',
                                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFFFF9900), width: 2),
                                  ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 方法2: Amazonで検索 → URLコピー
                  OutlinedButton.icon(
                    onPressed: _openAmazonSearch,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Amazonで商品を探す',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9900),
                      side: const BorderSide(color: Color(0xFFFF9900)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 方法3: 手動入力
                  ElevatedButton.icon(
                    onPressed: _scrollToNameField,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('手動で商品名を入力する',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                    imageUrl: _imageUrl,
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
          _buildSectionLabel('商品名 *', key: _nameFieldKey),
          const SizedBox(height: 4),
          Text('検索から自動入力されますが、手動で変更もできます',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
          const SizedBox(height: 4),
          Text('ガジェットの種類を分類できます。一覧画面でフィルタリングに使えます',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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

          // ── メモ ──
          _buildSectionLabel('メモ'),
          const SizedBox(height: 8),
          TextField(
            controller: _memoCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: _inputDecoration('使用感や気に入っているポイントなど').copyWith(alignLabelWithHint: true),
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

  Widget _buildSectionLabel(String text, {Key? key}) {
    return Text(text,
        key: key,
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

  static const _presetCategories = [
    'シューズ',
    'ボール',
    'ウェア',
    'サポーター',
    'バッグ',
    'プロテクター',
    'トレーニング用品',
    'その他',
  ];

  @override
  void dispose() {
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory([String? name]) async {
    name = name ?? _newCategoryCtrl.text.trim();
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

                    final existingNames = <String>{'カテゴリなし'};
                    if (snapshot.hasData) {
                      for (final doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? '';
                        categories.add({'id': doc.id, 'name': name});
                        existingNames.add(name);
                      }
                    }

                    // まだ追加されていないプリセットカテゴリ
                    final availablePresets = _presetCategories
                        .where((p) => !existingNames.contains(p))
                        .toList();

                    return ListView(
                      controller: scrollCtrl,
                      children: [
                        // プリセット候補チップ
                        if (availablePresets.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text('おすすめカテゴリ',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: availablePresets.map((preset) {
                                return ActionChip(
                                  avatar: const Icon(Icons.add, size: 16),
                                  label: Text(preset, style: const TextStyle(fontSize: 13)),
                                  onPressed: () => _addCategory(preset),
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                        ],

                        // 既存カテゴリ一覧
                        ...categories.map((cat) {
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
                        }),
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
}
