import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// リマインダー設定画面（管理者用）
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  // デフォルトのリマインダータイミング
  final List<Map<String, dynamic>> _timings = [
    {'key': '7days', 'label': '1週間前', 'enabled': false, 'daysBefore': 7, 'hoursBefore': 0},
    {'key': '3days', 'label': '3日前', 'enabled': false, 'daysBefore': 3, 'hoursBefore': 0},
    {'key': '1day', 'label': '前日', 'enabled': true, 'daysBefore': 1, 'hoursBefore': 0},
    {'key': 'morning', 'label': '当日朝9時', 'enabled': false, 'daysBefore': 0, 'hoursBefore': 0},
    {'key': '1hour', 'label': '1時間前', 'enabled': false, 'daysBefore': 0, 'hoursBefore': 1},
  ];

  String _messageTemplate = '{大会名}が{日時}に{会場}で開催されます。お忘れなく！';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('config').doc('reminderSettings').get();
      if (doc.exists) {
        final data = doc.data()!;
        final savedTimings = data['timings'] as List<dynamic>?;
        if (savedTimings != null) {
          for (final saved in savedTimings) {
            final savedMap = saved as Map<String, dynamic>;
            final index = _timings.indexWhere((t) => t['key'] == savedMap['key']);
            if (index >= 0) {
              _timings[index]['enabled'] = savedMap['enabled'] ?? false;
            }
          }
        }
        if (data['messageTemplate'] != null) {
          _messageTemplate = data['messageTemplate'] as String;
        }
      }
      _messageController.text = _messageTemplate;
    } catch (e) {
      debugPrint('リマインダー設定の読み込みエラー: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await _firestore.collection('config').doc('reminderSettings').set({
        'timings': _timings.map((t) => {
          'key': t['key'],
          'label': t['label'],
          'enabled': t['enabled'],
          'daysBefore': t['daysBefore'],
          'hoursBefore': t['hoursBefore'] ?? 0,
        }).toList(),
        'messageTemplate': _messageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  String _buildPreview() {
    String preview = _messageController.text;
    preview = preview.replaceAll('{大会名}', 'サンプル大会');
    preview = preview.replaceAll('{日時}', '2026/04/10 10:00');
    preview = preview.replaceAll('{会場}', '東京体育館');
    return preview;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('リマインダー設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // タイミング設定セクション
                _buildSectionTitle('通知タイミング', Icons.schedule_rounded),
                const SizedBox(height: 4),
                Text('大会開催日に対するリマインダー送信タイミング',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                _buildTimingsList(),
                const SizedBox(height: 24),

                // メッセージテンプレートセクション
                _buildSectionTitle('リマインダーメッセージ', Icons.message_rounded),
                const SizedBox(height: 4),
                Text('プレースホルダー: {大会名}, {日時}, {会場}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                _buildMessageTemplate(),
                const SizedBox(height: 16),

                // プレビュー
                _buildSectionTitle('プレビュー', Icons.preview_rounded),
                const SizedBox(height: 12),
                _buildPreviewCard(),
                const SizedBox(height: 32),

                // 保存ボタン
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('設定を保存',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildTimingsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _timings.asMap().entries.map((entry) {
          final index = entry.key;
          final timing = entry.value;
          final isLast = index == _timings.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: timing['enabled'] == true
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTimingIcon(timing['key'] as String),
                        size: 18,
                        color: timing['enabled'] == true
                            ? AppTheme.primaryColor
                            : AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timing['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: timing['enabled'] == true
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _getTimingDescription(timing['key'] as String),
                            style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: timing['enabled'] as bool,
                      onChanged: (val) {
                        setState(() {
                          _timings[index]['enabled'] = val;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, indent: 64, color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }

  IconData _getTimingIcon(String key) {
    switch (key) {
      case '7days':
        return Icons.calendar_month_rounded;
      case '3days':
        return Icons.date_range_rounded;
      case '1day':
        return Icons.today_rounded;
      case 'morning':
        return Icons.wb_sunny_rounded;
      case '1hour':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getTimingDescription(String key) {
    switch (key) {
      case '7days':
        return '大会の7日前に通知';
      case '3days':
        return '大会の3日前に通知';
      case '1day':
        return '大会の前日に通知';
      case 'morning':
        return '大会当日の朝9時に通知';
      case '1hour':
        return '大会開始の1時間前に通知';
      default:
        return '';
    }
  }

  Widget _buildMessageTemplate() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _messageController,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'リマインダーメッセージを入力...',
          hintStyle: TextStyle(color: AppTheme.textHint, fontSize: 14),
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
          contentPadding: const EdgeInsets.all(12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  size: 18, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text('通知プレビュー',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _buildPreview(),
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
