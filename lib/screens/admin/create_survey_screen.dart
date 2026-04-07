import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// アンケート作成画面（公式アカウント用）
class CreateSurveyScreen extends StatefulWidget {
  const CreateSurveyScreen({super.key});

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  // Each question: { textController, choices: [TextEditingController] }
  final List<_QuestionData> _questions = [_QuestionData()];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionData()));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _addChoice(int questionIndex) {
    setState(() {
      _questions[questionIndex].choices.add(TextEditingController());
    });
  }

  void _removeChoice(int questionIndex, int choiceIndex) {
    if (_questions[questionIndex].choices.length <= 2) return;
    setState(() {
      _questions[questionIndex].choices[choiceIndex].dispose();
      _questions[questionIndex].choices.removeAt(choiceIndex);
    });
  }

  Future<void> _save() async {
    // Validation
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('タイトルを入力してください');
      return;
    }

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        _showError('質問${i + 1}のテキストを入力してください');
        return;
      }
      final validChoices = q.choices
          .where((c) => c.text.trim().isNotEmpty)
          .toList();
      if (validChoices.length < 2) {
        _showError('質問${i + 1}には2つ以上の選択肢が必要です');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final questions = _questions.map((q) {
        final choices = q.choices
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        return {
          'text': q.textController.text.trim(),
          'choices': choices,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('surveys').add({
        'title': title,
        'description': _descriptionController.text.trim(),
        'questions': questions,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
        'responseCount': 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アンケートを作成しました'),
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
        title: const Text('アンケート作成',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            // Title field
            _buildLabel('タイトル', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: _inputDecoration('アンケートのタイトル'),
            ),
            const SizedBox(height: 16),

            // Description field
            _buildLabel('説明'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 3,
              decoration: _inputDecoration('アンケートの説明（任意）'),
            ),
            const SizedBox(height: 24),

            // Questions
            Row(
              children: [
                const Text('質問',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('質問を追加'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            for (int qi = 0; qi < _questions.length; qi++) ...[
              _buildQuestionCard(qi),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int qi) {
    final question = _questions[qi];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('${qi + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('質問',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              if (_questions.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  onPressed: () => _removeQuestion(qi),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: question.textController,
            decoration: _inputDecoration('質問を入力'),
          ),
          const SizedBox(height: 16),

          // Choices
          Row(
            children: [
              Text('選択肢',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _addChoice(qi),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 2),
                    Text('追加',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int ci = 0; ci < question.choices.length; ci++) ...[
            Row(
              children: [
                Icon(Icons.radio_button_unchecked,
                    size: 18, color: AppTheme.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: question.choices[ci],
                    decoration: InputDecoration(
                      hintText: '選択肢${ci + 1}',
                      hintStyle: TextStyle(color: AppTheme.textHint),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (question.choices.length > 2)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                    onPressed: () => _removeChoice(qi, ci),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
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

class _QuestionData {
  final TextEditingController textController = TextEditingController();
  final List<TextEditingController> choices = [
    TextEditingController(),
    TextEditingController(),
  ];

  void dispose() {
    textController.dispose();
    for (final c in choices) {
      c.dispose();
    }
  }
}
