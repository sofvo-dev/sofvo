import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// スポンサー管理画面（公式アカウント用）
class SponsorManagementScreen extends StatelessWidget {
  const SponsorManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('スポンサー管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showSponsorForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sponsors')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('スポンサーはありません',
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('右下の＋ボタンから追加できます',
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _SponsorCard(
                docId: doc.id,
                data: data,
                onEdit: () =>
                    _showSponsorForm(context, docId: doc.id, data: data),
                onToggleActive: () => _toggleActive(doc.id, data),
                onDelete: () => _confirmDelete(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('sponsors')
        .doc(docId)
        .update({'active': !(data['active'] == true)});
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('スポンサーを削除'),
        content:
            Text('「${data['name'] ?? ''}」を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(docId)
          .delete();
    }
  }

  void _showSponsorForm(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SponsorFormScreen(docId: docId, initialData: data),
      ),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SponsorCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final linkUrl = data['linkUrl'] as String? ?? '';
    final order = data['order'] as int? ?? 0;
    final active = data['active'] == true;

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        active ? '表示中' : '非表示',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? AppTheme.success : AppTheme.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (_) => onToggleActive(),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 60,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(Icons.broken_image,
                              color: AppTheme.textHint),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.link, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(linkUrl,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('表示順: $order',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SponsorFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const _SponsorFormScreen({this.docId, this.initialData});

  @override
  State<_SponsorFormScreen> createState() => _SponsorFormScreenState();
}

class _SponsorFormScreenState extends State<_SponsorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _linkUrlController;
  late final TextEditingController _orderController;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d?['name'] as String? ?? '');
    _imageUrlController =
        TextEditingController(text: d?['imageUrl'] as String? ?? '');
    _linkUrlController =
        TextEditingController(text: d?['linkUrl'] as String? ?? '');
    _orderController =
        TextEditingController(text: '${d?['order'] as int? ?? 0}');
    _active = d?['active'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _linkUrlController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'linkUrl': _linkUrlController.text.trim(),
      'order': int.tryParse(_orderController.text.trim()) ?? 0,
      'active': _active,
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('sponsors')
            .doc(widget.docId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('sponsors').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditing ? 'スポンサー編集' : 'スポンサー追加',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('保存',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildLabel('企業名'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              decoration: _inputDecoration('企業名を入力'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '企業名を入力してください' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('バナー画像URL'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _imageUrlController,
              decoration: _inputDecoration('https://example.com/banner.png'),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '画像URLを入力してください' : null,
            ),
            if (_imageUrlController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageUrlController.text.trim(),
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('画像を読み込めません',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textHint)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildLabel('リンクURL'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _linkUrlController,
              decoration: _inputDecoration('https://example.com'),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'リンクURLを入力してください' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('表示順'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orderController,
              decoration: _inputDecoration('0'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('アクティブ'),
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textHint),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }
}
