import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// FAQ管理画面（管理者用）
class FaqManagementScreen extends StatelessWidget {
  const FaqManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('FAQ管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showFaqForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faq')
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
                  Icon(Icons.quiz_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('FAQはありません',
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

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(docs, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _FaqCard(
                key: ValueKey(doc.id),
                docId: doc.id,
                data: data,
                onEdit: () =>
                    _showFaqForm(context, docId: doc.id, data: data),
                onDelete: () => _confirmDelete(context, doc.id, data),
                onToggleActive: () => _toggleActive(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onReorder(
      List<QueryDocumentSnapshot> docs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final movedDoc = docs[oldIndex];
    final batch = FirebaseFirestore.instance.batch();

    // Build new order list
    final ids = docs.map((d) => d.id).toList();
    ids.removeAt(oldIndex);
    ids.insert(newIndex, movedDoc.id);

    for (int i = 0; i < ids.length; i++) {
      batch.update(
        FirebaseFirestore.instance.collection('faq').doc(ids[i]),
        {'order': i},
      );
    }
    await batch.commit();
  }

  Future<void> _toggleActive(BuildContext context, String docId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('faq')
          .doc(docId)
          .update({'active': !(data['active'] == true)});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('操作に失敗しました'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('FAQを削除'),
        content: Text(
            '「${data['question'] ?? ''}」を削除しますか？この操作は取り消せません。'),
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
      try {
        await FirebaseFirestore.instance.collection('faq').doc(docId).delete();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('操作に失敗しました'),
              backgroundColor: AppTheme.error));
        }
      }
    }
  }

  void _showFaqForm(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FaqFormScreen(docId: docId, initialData: data),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _FaqCard({
    super.key,
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final question = data['question'] as String? ?? '';
    final answer = data['answer'] as String? ?? '';
    final category = data['category'] as String? ?? '一般';
    final active = data['active'] == true;
    final order = data['order'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key('dismiss_$docId'),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.drag_handle,
                          size: 20, color: AppTheme.textHint),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(category,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor)),
                      ),
                      const SizedBox(width: 8),
                      Text('#$order',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textHint)),
                      const Spacer(),
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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                active ? AppTheme.success : AppTheme.textHint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: active,
                        onChanged: (_) => onToggleActive(),
                        activeColor: AppTheme.primaryColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Q: $question',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('A: $answer',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const _FaqFormScreen({this.docId, this.initialData});

  @override
  State<_FaqFormScreen> createState() => _FaqFormScreenState();
}

class _FaqFormScreenState extends State<_FaqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  late final TextEditingController _orderController;
  late String _selectedCategory;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;

  static const _categories = ['一般', 'アカウント', '大会', 'チャット', 'ポイント'];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _questionController =
        TextEditingController(text: d?['question'] as String? ?? '');
    _answerController =
        TextEditingController(text: d?['answer'] as String? ?? '');
    _orderController =
        TextEditingController(text: '${d?['order'] as int? ?? 0}');
    _selectedCategory = d?['category'] as String? ?? '一般';
    _active = d?['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'question': _questionController.text.trim(),
      'answer': _answerController.text.trim(),
      'category': _selectedCategory,
      'order': int.tryParse(_orderController.text.trim()) ?? 0,
      'active': _active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('faq')
            .doc(widget.docId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('faq').add(data);
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
        title: Text(_isEditing ? 'FAQ編集' : 'FAQ追加',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
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
            // ── カテゴリ ──
            _buildLabel('カテゴリ'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 質問 ──
            _buildLabel('質問'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _questionController,
              maxLines: 3,
              maxLength: 200,
              decoration: _inputDecoration('質問を入力'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '質問を入力してください' : null,
            ),
            const SizedBox(height: 20),

            // ── 回答 ──
            _buildLabel('回答'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _answerController,
              maxLines: 6,
              maxLength: 1000,
              decoration: _inputDecoration('回答を入力'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '回答を入力してください' : null,
            ),
            const SizedBox(height: 20),

            // ── 表示順 ──
            _buildLabel('表示順'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orderController,
              decoration: _inputDecoration('0'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // ── アクティブ ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('表示する'),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
