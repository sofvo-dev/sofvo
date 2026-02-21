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
        onPressed: () => _showCreateDialog(context, uid),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('テンプレートがありません',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('よく使う大会設定をテンプレートとして保存できます',
                      style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            );
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

  Widget _buildTemplateCard(
      BuildContext context, String uid, String docId, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'テンプレート') as String;
    final type = (data['type'] ?? '') as String;
    final maxTeams = data['maxTeams'] ?? 8;
    final location = (data['location'] ?? '') as String;
    final memo = (data['memo'] ?? '') as String;

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
                    _showEditDialog(context, uid, docId, data);
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

  void _showCreateDialog(BuildContext context, String uid) {
    _showTemplateDialog(context, uid, null, {});
  }

  void _showEditDialog(BuildContext context, String uid, String docId, Map<String, dynamic> data) {
    _showTemplateDialog(context, uid, docId, data);
  }

  void _showTemplateDialog(
      BuildContext context, String uid, String? docId, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: (data['name'] ?? '') as String);
    final typeCtrl = TextEditingController(text: (data['type'] ?? '') as String);
    final teamsCtrl = TextEditingController(text: '${data['maxTeams'] ?? 8}');
    final locationCtrl = TextEditingController(text: (data['location'] ?? '') as String);
    final memoCtrl = TextEditingController(text: (data['memo'] ?? '') as String);
    final isNew = docId == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isNew ? 'テンプレート作成' : 'テンプレート編集',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'テンプレート名'),
              const SizedBox(height: 10),
              _dialogField(typeCtrl, '大会タイプ（例: リーグ戦）'),
              const SizedBox(height: 10),
              _dialogField(teamsCtrl, '最大チーム数', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _dialogField(locationCtrl, '会場'),
              const SizedBox(height: 10),
              _dialogField(memoCtrl, 'メモ', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final templateData = {
                'name': nameCtrl.text.trim(),
                'type': typeCtrl.text.trim(),
                'maxTeams': int.tryParse(teamsCtrl.text) ?? 8,
                'location': locationCtrl.text.trim(),
                'memo': memoCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              final ref = FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('templates');

              if (isNew) {
                templateData['createdAt'] = FieldValue.serverTimestamp();
                await ref.add(templateData);
              } else {
                await ref.doc(docId).update(templateData);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isNew ? '作成' : '保存'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint,
      {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
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
