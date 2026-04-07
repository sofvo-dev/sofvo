import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 大会テンプレート管理画面（公式アカウント用）
class TournamentTemplateScreen extends StatelessWidget {
  const TournamentTemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('大会テンプレート',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const _TournamentTemplateFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournamentTemplates')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('テンプレートはありません',
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('右下の＋ボタンから作成できます',
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
              return _TemplateCard(
                docId: doc.id,
                data: data,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TournamentTemplateFormScreen(
                      docId: doc.id,
                      initialData: data,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ━━━ テンプレートカード ━━━

class _TemplateCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.docId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    final teamCount = data['teamCount'] as int? ?? 0;
    final usageCount = data['usageCount'] as int? ?? 0;

    return Dismissible(
      key: ValueKey(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('削除',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('テンプレートを削除'),
            content: Text('「$name」を削除しますか？'),
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
              .collection('tournamentTemplates')
              .doc(docId)
              .delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('テンプレートを削除しました'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.textSecondary,
              ),
            );
          }
        }
        return false;
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      color: Colors.cyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (description.isNotEmpty)
                        Text(description,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '$type  ・  ${teamCount}チーム  ・  使用${usageCount}回',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━ テンプレート作成・編集フォーム ━━━

class _TournamentTemplateFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const _TournamentTemplateFormScreen({this.docId, this.initialData});

  @override
  State<_TournamentTemplateFormScreen> createState() =>
      _TournamentTemplateFormScreenState();
}

class _TournamentTemplateFormScreenState
    extends State<_TournamentTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _teamCountController = TextEditingController();
  final _rulesController = TextEditingController();
  String _selectedType = '一般';
  bool _isSaving = false;

  static const _typeOptions = ['一般', '男子', '女子', 'ミックス'];

  bool get _isEditing => widget.docId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nameController.text = d['name'] as String? ?? '';
      _descriptionController.text = d['description'] as String? ?? '';
      _teamCountController.text = (d['teamCount'] as int?)?.toString() ?? '';
      _rulesController.text = d['rules'] as String? ?? '';
      final type = d['type'] as String? ?? '一般';
      if (_typeOptions.contains(type)) _selectedType = type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _teamCountController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'teamCount': int.tryParse(_teamCountController.text.trim()) ?? 0,
        'rules': _rulesController.text.trim(),
      };

      final collection =
          FirebaseFirestore.instance.collection('tournamentTemplates');

      if (_isEditing) {
        await collection.doc(widget.docId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['usageCount'] = 0;
        await collection.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'テンプレートを更新しました' : 'テンプレートを作成しました'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'テンプレートを編集' : 'テンプレートを作成',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('保存',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLabel('テンプレート名'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              decoration: _inputDecoration('例: ビーチバレー4チームトーナメント'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'テンプレート名を入力してください' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('説明'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 3,
              decoration: _inputDecoration('テンプレートの説明を入力'),
            ),
            const SizedBox(height: 16),
            _buildLabel('大会タイプ'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration(null),
              items: _typeOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 16),
            _buildLabel('チーム数'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _teamCountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration('例: 8'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'チーム数を入力してください';
                final n = int.tryParse(v.trim());
                if (n == null || n < 2) return '2以上の数を入力してください';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildLabel('ルール説明'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rulesController,
              maxLength: 500,
              maxLines: 6,
              decoration: _inputDecoration('大会ルールの説明を入力'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary));
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
