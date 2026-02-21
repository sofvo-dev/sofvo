import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// テンプレート管理画面（大会作成テンプレート）
class TemplateManagementScreen extends StatelessWidget {
  const TemplateManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('テンプレート管理')),
        body: const Center(child: Text('ログインしてください')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('テンプレート管理')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => _TemplateEditScreen(uid: uid))),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('templates')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final templates = snapshot.data?.docs ?? [];
          if (templates.isEmpty) {
            return _buildEmptyState(context, uid);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = templates[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildTemplateCard(context, uid, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String uid) {
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
            child: const Icon(Icons.description_outlined, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          const Text('テンプレートがありません',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('よく使う大会設定をテンプレートとして\n保存できます',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => _TemplateEditScreen(uid: uid))),
            icon: const Icon(Icons.add),
            label: const Text('テンプレートを作成'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
      BuildContext context, String uid, String docId, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'テンプレート') as String;
    final type = (data['type'] ?? '') as String;
    final maxTeams = data['maxTeams'] ?? 8;
    final location = (data['location'] ?? '') as String;
    final memo = (data['memo'] ?? '') as String;
    final format = (data['format'] ?? '') as String;
    final setCount = (data['setCount'] ?? '') as String;
    final pointsPerSet = (data['pointsPerSet'] ?? '') as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    if (type.isNotEmpty)
                      Text(type, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _TemplateEditScreen(uid: uid, docId: docId, data: data)));
                  } else if (value == 'delete') {
                    _confirmDelete(context, uid, docId);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('編集')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('削除', style: TextStyle(color: AppTheme.error)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _infoChip(Icons.group, '$maxTeamsチーム'),
              if (format.isNotEmpty) _infoChip(Icons.category_outlined, format),
              if (setCount.isNotEmpty) _infoChip(Icons.sports_volleyball, '$setCountセット'),
              if (pointsPerSet.isNotEmpty) _infoChip(Icons.scoreboard_outlined, '$pointsPerSet点制'),
              if (location.isNotEmpty) _infoChip(Icons.place, location),
            ],
          ),
          if (memo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(memo,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String uid, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('テンプレート削除',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text('このテンプレートを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('templates')
                  .doc(docId)
                  .delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// テンプレート作成・編集画面（フルスクリーン）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _TemplateEditScreen extends StatefulWidget {
  final String uid;
  final String? docId;
  final Map<String, dynamic> data;

  const _TemplateEditScreen({
    required this.uid,
    this.docId,
    this.data = const {},
  });

  @override
  State<_TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<_TemplateEditScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _memoCtrl;

  String _type = '';
  String _format = '';
  int _maxTeams = 8;
  String _setCount = '3';
  String _pointsPerSet = '25';
  bool _isSaving = false;

  bool get _isNew => widget.docId == null;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: (d['name'] ?? '') as String);
    _locationCtrl = TextEditingController(text: (d['location'] ?? '') as String);
    _memoCtrl = TextEditingController(text: (d['memo'] ?? '') as String);
    _type = (d['type'] ?? '') as String;
    _format = (d['format'] ?? '') as String;
    _maxTeams = (d['maxTeams'] is int) ? d['maxTeams'] : 8;
    _setCount = (d['setCount'] ?? '3') as String;
    _pointsPerSet = (d['pointsPerSet'] ?? '25') as String;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレート名を入力してください'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final templateData = {
        'name': name,
        'type': _type,
        'format': _format,
        'maxTeams': _maxTeams,
        'setCount': _setCount,
        'pointsPerSet': _pointsPerSet,
        'location': _locationCtrl.text.trim(),
        'memo': _memoCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('templates');

      if (_isNew) {
        templateData['createdAt'] = FieldValue.serverTimestamp();
        await ref.add(templateData);
      } else {
        await ref.doc(widget.docId).update(templateData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isNew ? 'テンプレート作成' : 'テンプレート編集'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isNew ? '作成' : '保存',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── テンプレート名 ──
            _buildSectionLabel('テンプレート名', required_: true),
            const SizedBox(height: 4),
            _buildHint('保存名を入力してください（例: 週末リーグ戦設定）'),
            const SizedBox(height: 8),
            _buildTextField(_nameCtrl, '例: 週末リーグ戦設定'),
            const SizedBox(height: 20),

            // ── 大会タイプ ──
            _buildSectionLabel('大会タイプ'),
            const SizedBox(height: 4),
            _buildHint('大会の種別を選択してください'),
            const SizedBox(height: 8),
            _buildChipSelector(
              options: ['練習試合', 'リーグ戦', 'トーナメント', 'カップ戦', 'フレンドマッチ'],
              selected: _type,
              onSelected: (val) => setState(() => _type = val),
            ),
            const SizedBox(height: 20),

            // ── 試合形式 ──
            _buildSectionLabel('試合形式'),
            const SizedBox(height: 4),
            _buildHint('対戦の形式を選択してください'),
            const SizedBox(height: 8),
            _buildChipSelector(
              options: ['総当たり', 'トーナメント', 'スイスドロー', 'ダブルエリミネーション'],
              selected: _format,
              onSelected: (val) => setState(() => _format = val),
            ),
            const SizedBox(height: 20),

            // ── チーム数 ──
            _buildSectionLabel('最大チーム数'),
            const SizedBox(height: 4),
            _buildHint('参加できるチーム数の上限'),
            const SizedBox(height: 8),
            _buildChipSelector(
              options: ['4', '6', '8', '10', '12', '16'],
              selected: '$_maxTeams',
              onSelected: (val) => setState(() => _maxTeams = int.tryParse(val) ?? 8),
            ),
            const SizedBox(height: 20),

            // ── セット数 ──
            _buildSectionLabel('セット数'),
            const SizedBox(height: 4),
            _buildHint('1試合あたりのセット数'),
            const SizedBox(height: 8),
            _buildChipSelector(
              options: ['1', '3', '5'],
              selected: _setCount,
              onSelected: (val) => setState(() => _setCount = val),
            ),
            const SizedBox(height: 20),

            // ── 1セットの得点 ──
            _buildSectionLabel('1セットの得点'),
            const SizedBox(height: 4),
            _buildHint('何点先取でセットを獲得するか'),
            const SizedBox(height: 8),
            _buildChipSelector(
              options: ['15', '21', '25'],
              selected: _pointsPerSet,
              onSelected: (val) => setState(() => _pointsPerSet = val),
            ),
            const SizedBox(height: 20),

            // ── 会場 ──
            _buildSectionLabel('会場'),
            const SizedBox(height: 4),
            _buildHint('よく使う会場名を保存しておけます'),
            const SizedBox(height: 8),
            _buildTextField(_locationCtrl, '例: ○○市体育館'),
            const SizedBox(height: 20),

            // ── メモ ──
            _buildSectionLabel('メモ'),
            const SizedBox(height: 4),
            _buildHint('このテンプレートの補足情報'),
            const SizedBox(height: 8),
            _buildTextField(_memoCtrl, '例: 毎月第2土曜の練習試合用', maxLines: 3),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {bool required_ = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        if (required_) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('必須', style: TextStyle(fontSize: 10, color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildHint(String text) {
    return Text(text, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
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
      ),
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == selected;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => onSelected(isSelected ? '' : option),
          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 14,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
          ),
          backgroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
