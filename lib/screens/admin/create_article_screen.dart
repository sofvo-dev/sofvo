import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';

/// 記事作成・編集画面（公式アカウント用）
class CreateArticleScreen extends StatefulWidget {
  final String? articleId;
  final Map<String, dynamic>? existingData;

  const CreateArticleScreen({super.key, this.articleId, this.existingData});

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  bool _isSaving = false;

  String _selectedCategory = 'コラム';
  static const List<String> _categories = [
    'ルール解説',
    '練習方法',
    '大会レポート',
    'コラム',
    'その他',
  ];

  bool get _isEditing => widget.articleId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _titleController.text = data['title'] as String? ?? '';
      _bodyController.text = data['body'] as String? ?? '';
      _thumbnailUrlController.text = data['thumbnailUrl'] as String? ?? '';
      final cat = data['category'] as String?;
      if (cat != null && _categories.contains(cat)) {
        _selectedCategory = cat;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showError('タイトルを入力してください');
      return;
    }
    if (body.isEmpty) {
      _showError('本文を入力してください');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final articleData = <String, dynamic>{
        'title': title,
        'category': _selectedCategory,
        'body': body,
        'thumbnailUrl': _thumbnailUrlController.text.trim(),
        'authorId': uid,
        'published': true,
      };

      if (_isEditing) {
        articleData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('articles')
            .doc(widget.articleId)
            .update(articleData);
      } else {
        articleData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('articles')
            .add(articleData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? '記事を更新しました' : '記事を作成しました'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? '記事編集' : '記事作成',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('保存',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            _buildLabel('タイトル', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              maxLength: 100,
              decoration: _inputDecoration('記事のタイトル'),
            ),
            const SizedBox(height: 16),

            // Category
            _buildLabel('カテゴリ', required: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Body
            _buildLabel('本文', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              maxLength: 5000,
              maxLines: 15,
              decoration: _inputDecoration('記事の本文'),
            ),
            const SizedBox(height: 16),

            // Thumbnail URL
            _buildLabel('サムネイルURL'),
            const SizedBox(height: 8),
            TextField(
              controller: _thumbnailUrlController,
              decoration: _inputDecoration('https://example.com/image.jpg'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        if (required)
          const Text(' *',
              style: TextStyle(color: AppTheme.error, fontSize: 14)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textHint),
      filled: true,
      fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
