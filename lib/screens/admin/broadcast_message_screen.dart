import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../config/app_theme.dart';

/// ブロードキャストメッセージ送信画面（公式アカウント用）
class BroadcastMessageScreen extends StatefulWidget {
  const BroadcastMessageScreen({super.key});

  @override
  State<BroadcastMessageScreen> createState() => _BroadcastMessageScreenState();
}

class _BroadcastMessageScreenState extends State<BroadcastMessageScreen> {
  final _messageController = TextEditingController();
  String _selectedTarget = 'all';
  int? _estimatedCount;
  bool _loadingCount = false;
  bool _sending = false;

  static const Map<String, String> _targetLabels = {
    'all': '全ユーザー',
    'active': 'アクティブ（30日以内）',
    'beginner': '初心者（1年未満）',
    'dormant': '休眠（30日以上未活動）',
  };

  @override
  void initState() {
    super.initState();
    _loadEstimatedCount();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadEstimatedCount() async {
    setState(() => _loadingCount = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final thirtyDaysAgoTs = Timestamp.fromDate(thirtyDaysAgo);

      int count;
      switch (_selectedTarget) {
        case 'active':
          final snap = await db
              .collection('users')
              .where('lastActiveAt', isGreaterThanOrEqualTo: thirtyDaysAgoTs)
              .count()
              .get();
          count = snap.count ?? 0;
          break;
        case 'beginner':
          final snap = await db
              .collection('users')
              .where('experience', isEqualTo: '1年未満')
              .count()
              .get();
          count = snap.count ?? 0;
          break;
        case 'dormant':
          final snap = await db
              .collection('users')
              .where('lastActiveAt', isLessThan: thirtyDaysAgoTs)
              .count()
              .get();
          count = snap.count ?? 0;
          break;
        default:
          final snap = await db.collection('users').count().get();
          count = snap.count ?? 0;
      }
      if (mounted) setState(() => _estimatedCount = count);
    } catch (_) {
      if (mounted) setState(() => _estimatedCount = null);
    } finally {
      if (mounted) setState(() => _loadingCount = false);
    }
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メッセージを送信'),
        content: Text(
          '${_targetLabels[_selectedTarget]}（推定${_estimatedCount ?? "?"}人）にメッセージを送信しますか？\n\n「$message」',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('broadcastChatMessage');
      final result = await callable.call({
        'message': message,
        'target': _selectedTarget,
      });
      final sentCount = result.data['sentCount'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$sentCount 人にメッセージを送信しました'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.success,
          ),
        );
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信に失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
        title: const Text('ブロードキャスト送信',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── ターゲット選択 ──
          _buildLabel('送信対象'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: _targetLabels.entries.map((entry) {
                final isSelected = _selectedTarget == entry.key;
                return RadioListTile<String>(
                  title: Text(entry.value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: AppTheme.textPrimary,
                      )),
                  value: entry.key,
                  groupValue: _selectedTarget,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedTarget = v);
                      _loadEstimatedCount();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── 推定人数 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: AppTheme.accentColor, size: 20),
                const SizedBox(width: 8),
                _loadingCount
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accentColor))
                    : Text(
                        '推定送信先: ${_estimatedCount ?? "---"} 人',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── メッセージ入力 ──
          _buildLabel('メッセージ内容'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _messageController,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'メッセージを入力してください...',
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
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),

          // ── 送信ボタン ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending || _messageController.text.trim().isEmpty
                  ? null
                  : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_sending ? '送信中...' : 'メッセージを送信'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
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
}
