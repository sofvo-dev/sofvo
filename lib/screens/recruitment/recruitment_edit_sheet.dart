import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// メンバー募集の編集（投稿者本人・公式アカウント）
class RecruitmentEditSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initial;

  const RecruitmentEditSheet({
    super.key,
    required this.docId,
    required this.initial,
  });

  @override
  State<RecruitmentEditSheet> createState() => _RecruitmentEditSheetState();
}

class _RecruitmentEditSheetState extends State<RecruitmentEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _messageCtrl;
  late final TextEditingController _neededCtrl;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    final needed = (d['needed'] as num?)?.toInt() ??
        (d['recruitCount'] as num?)?.toInt() ??
        1;
    _titleCtrl = TextEditingController(text: (d['title'] as String?) ?? '');
    _messageCtrl = TextEditingController(
      text: (d['message'] as String?)?.trim().isNotEmpty == true
          ? d['message'] as String
          : (d['comment'] as String?) ?? '',
    );
    _neededCtrl = TextEditingController(text: needed.toString());
    _status = (d['status'] as String?) ?? '募集中';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _neededCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final needed = int.tryParse(_neededCtrl.text.trim());
    if (needed == null || needed < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('募集人数は1以上の数字で入力してください'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final message = _messageCtrl.text.trim();
      await FirebaseFirestore.instance
          .collection('recruitments')
          .doc(widget.docId)
          .update({
        'title': _titleCtrl.text.trim(),
        'message': message,
        'comment': message,
        'needed': needed,
        'recruitCount': needed,
        'status': _status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('募集内容を更新しました'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('募集を編集',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('タイトル（任意）',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: '例: セッター募集',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text('募集人数',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _neededCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '1',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text('ステータス',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _status == '締切' ? '締切' : '募集中',
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: '募集中', child: Text('募集中')),
                DropdownMenuItem(value: '締切', child: Text('締切')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),
            const Text('メッセージ',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '募集内容',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
