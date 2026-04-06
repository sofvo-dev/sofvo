import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// お知らせ一斉配信画面（公式アカウント用）
class CreateNoticeScreen extends StatefulWidget {
  const CreateNoticeScreen({super.key});

  @override
  State<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends State<CreateNoticeScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedType = 'info';
  int _selectedTemplateIndex = 0;
  bool _isPinned = false;
  bool _isSending = false;

  static const _noticeTemplates = <String, List<Map<String, String>>>{
    'info': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': 'イベント告知', 'title': 'イベントのお知らせ', 'body': '下記の日程でイベントを開催します。\n\n日時: \n場所: \n内容: \n\n皆様のご参加をお待ちしております！'},
      {'label': 'ルール変更', 'title': 'ルール変更のお知らせ', 'body': '以下のルールが変更されました。\n\n【変更点】\n・\n\n【適用日】\n\nご不明点があればお問い合わせください。'},
    ],
    'release': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': '新機能リリース', 'title': '新機能リリースのお知らせ', 'body': '新しい機能が追加されました！\n\n【新機能】\n・\n\nぜひお試しください！'},
      {'label': '正式リリース', 'title': 'Sofvo 正式リリースのお知らせ', 'body': 'ソフトバレーボール マッチングアプリ「Sofvo」をご利用いただきありがとうございます。大会検索・メンバー募集・チャットなどの機能をお楽しみください。'},
    ],
    'update': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': 'アップデート', 'title': 'バージョン アップデート', 'body': '以下の機能が改善されました。\n\n【改善点】\n・\n\nアプリを最新版に更新してご利用ください。'},
      {'label': '不具合修正', 'title': '不具合修正のお知らせ', 'body': '以下の不具合を修正しました。\n\n【修正内容】\n・\n\nご不便をおかけして申し訳ございませんでした。'},
    ],
    'maintenance': [
      {'label': '自由入力', 'title': '', 'body': ''},
      {'label': '定期メンテナンス', 'title': 'メンテナンスのお知らせ', 'body': '下記の日時にメンテナンスを実施します。\n\n日時: 月 日（ ） 00:00 〜 00:00\n\nメンテナンス中はサービスをご利用いただけません。ご迷惑をおかけしますが、ご了承ください。'},
      {'label': '緊急メンテナンス', 'title': '緊急メンテナンスのお知らせ', 'body': '現在、緊急メンテナンスを実施中です。\n\n復旧予定: 月 日（ ） 00:00\n\nご不便をおかけして申し訳ございません。復旧次第お知らせいたします。'},
    ],
  };

  static const _noticeTypeOptions = [
    {'value': 'info', 'label': 'お知らせ', 'icon': Icons.info_outline, 'color': 0xFF1B3A5C},
    {'value': 'release', 'label': 'リリース', 'icon': Icons.campaign, 'color': 0xFFC4A962},
    {'value': 'update', 'label': 'アップデート', 'icon': Icons.update, 'color': 0xFF1565C0},
    {'value': 'maintenance', 'label': 'メンテナンス', 'icon': Icons.build, 'color': 0xFFF9A825},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(int index) {
    final templates = _noticeTemplates[_selectedType] ?? _noticeTemplates['info']!;
    setState(() => _selectedTemplateIndex = index);
    final t = templates[index];
    _titleController.text = t['title'] ?? '';
    _bodyController.text = t['body'] ?? '';
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルと本文を入力してください'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('notices').add({
        'type': _selectedType,
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        if (_isPinned) 'pinned': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お知らせを配信しました'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('配信に失敗しました: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = _noticeTemplates[_selectedType] ?? _noticeTemplates['info']!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('お知らせ配信', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 種類
            Text('種類', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: _noticeTypeOptions.map((opt) {
                final value = opt['value'] as String;
                final label = opt['label'] as String;
                final icon = opt['icon'] as IconData;
                final color = Color(opt['color'] as int);
                final isSelected = value == _selectedType;
                return GestureDetector(
                  onTap: () {
                    setState(() { _selectedType = value; _selectedTemplateIndex = 0; });
                    _applyTemplate(0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: isSelected ? color : AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color : AppTheme.textSecondary,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ピン留め
            Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                value: _isPinned,
                onChanged: (v) => setState(() => _isPinned = v),
                title: const Text('ピン留め', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('お知らせ一覧の上部に固定表示します', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                secondary: Icon(Icons.push_pin, color: _isPinned ? AppTheme.primaryColor : AppTheme.textSecondary, size: 22),
                activeColor: AppTheme.primaryColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // テンプレート
            if (templates.length > 1) ...[
              Text('テンプレート', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedTemplateIndex,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                    items: List.generate(templates.length, (i) => DropdownMenuItem(
                      value: i,
                      child: Text(templates[i]['label']!, style: const TextStyle(fontSize: 14)),
                    )),
                    onChanged: (i) {
                      if (i != null) _applyTemplate(i);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // タイトル
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'タイトルを入力',
                hintStyle: TextStyle(color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                counterText: '',
              ),
              maxLength: 50,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // 本文
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                hintText: '本文を入力',
                hintStyle: TextStyle(color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                counterStyle: TextStyle(color: AppTheme.textHint, fontSize: 11),
              ),
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),

            // 配信ボタン
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('配信する', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
