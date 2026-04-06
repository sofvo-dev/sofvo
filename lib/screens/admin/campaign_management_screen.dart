import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// キャンペーン管理画面（管理者用）
class CampaignManagementScreen extends StatelessWidget {
  const CampaignManagementScreen({super.key});

  /// startDate / endDate と現在日時からステータスを判定
  static String _statusLabel(Map<String, dynamic> data) {
    final active = data['active'] == true;
    if (!active) return '無効';

    final now = DateTime.now();
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();

    if (startDate != null && now.isBefore(startDate)) return '予約済み';
    if (endDate != null && now.isAfter(endDate)) return '終了';
    return '配信中';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case '配信中':
        return AppTheme.success;
      case '予約済み':
        return AppTheme.info;
      case '終了':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _typeLabel(String? type) {
    switch (type) {
      case 'banner':
        return 'バナー';
      case 'popup':
        return 'ポップアップ';
      case 'promotion':
        return 'プロモーション';
      default:
        return type ?? '';
    }
  }

  static Color _typeColor(String? type) {
    switch (type) {
      case 'banner':
        return AppTheme.primaryColor;
      case 'popup':
        return AppTheme.accentColor;
      case 'promotion':
        return AppTheme.warning;
      default:
        return Colors.grey;
    }
  }

  static String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('キャンペーン管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showCampaignForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campaigns')
            .orderBy('startDate', descending: true)
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
                  Icon(Icons.campaign_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('キャンペーンはありません',
                      style: TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('右下の+ボタンから追加できます',
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
              return _CampaignCard(
                docId: doc.id,
                data: data,
                onEdit: () =>
                    _showCampaignForm(context, docId: doc.id, data: data),
                onDelete: () => _confirmDelete(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('キャンペーンを削除'),
        content: Text(
            '「${data['title'] ?? ''}」を削除しますか？この操作は取り消せません。'),
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
          .collection('campaigns')
          .doc(docId)
          .delete();
    }
  }

  void _showCampaignForm(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _CampaignFormScreen(docId: docId, initialData: data),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CampaignCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final type = data['type'] as String?;
    final startDate = data['startDate'] as Timestamp?;
    final endDate = data['endDate'] as Timestamp?;
    final status = CampaignManagementScreen._statusLabel(data);
    final statusColor = CampaignManagementScreen._statusColor(status);
    final typeLabel = CampaignManagementScreen._typeLabel(type);
    final typeColor = CampaignManagementScreen._typeColor(type);
    final imageUrl = data['imageUrl'] as String? ?? '';
    final targetScreen = data['targetScreen'] as String? ?? '';

    return Dismissible(
      key: Key(docId),
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
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 60,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(Icons.broken_image,
                              color: AppTheme.textHint),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.date_range, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Text(
                      '${CampaignManagementScreen._formatDate(startDate)} ~ ${CampaignManagementScreen._formatDate(endDate)}',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Icon(Icons.screen_share_outlined,
                        size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Text(targetScreen,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CampaignFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const _CampaignFormScreen({this.docId, this.initialData});

  @override
  State<_CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends State<_CampaignFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _linkUrlController;
  late String _type;
  late String _targetScreen;
  late bool _active;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  bool get _isEditing => widget.docId != null;

  static const _types = [
    {'value': 'banner', 'label': 'バナー'},
    {'value': 'popup', 'label': 'ポップアップ'},
    {'value': 'promotion', 'label': 'プロモーション'},
  ];

  static const _targetScreens = [
    {'value': 'ホーム', 'label': 'ホーム'},
    {'value': '大会一覧', 'label': '大会一覧'},
    {'value': 'チャット', 'label': 'チャット'},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _titleController =
        TextEditingController(text: d?['title'] as String? ?? '');
    _descriptionController =
        TextEditingController(text: d?['description'] as String? ?? '');
    _imageUrlController =
        TextEditingController(text: d?['imageUrl'] as String? ?? '');
    _linkUrlController =
        TextEditingController(text: d?['linkUrl'] as String? ?? '');
    _type = d?['type'] as String? ?? 'banner';
    _targetScreen = d?['targetScreen'] as String? ?? 'ホーム';
    _active = d?['active'] as bool? ?? true;
    _startDate = (d?['startDate'] as Timestamp?)?.toDate();
    _endDate = (d?['endDate'] as Timestamp?)?.toDate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _linkUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '未設定';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _type,
      'imageUrl': _imageUrlController.text.trim(),
      'linkUrl': _linkUrlController.text.trim(),
      'startDate':
          _startDate != null ? Timestamp.fromDate(_startDate!) : null,
      'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      'targetScreen': _targetScreen,
      'active': _active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('campaigns')
            .doc(widget.docId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('campaigns').add(data);
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
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditing ? 'キャンペーン編集' : 'キャンペーン追加',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
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
            _buildLabel('タイトル'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: _inputDecoration('キャンペーンタイトルを入力'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('説明'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _inputDecoration('キャンペーンの説明（任意）'),
            ),
            const SizedBox(height: 20),
            _buildLabel('タイプ'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  items: _types
                      .map((t) => DropdownMenuItem(
                          value: t['value'], child: Text(t['label']!)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('バナー画像URL'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _imageUrlController,
              decoration: _inputDecoration('https://example.com/banner.png'),
              keyboardType: TextInputType.url,
            ),
            if (_imageUrlController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageUrlController.text.trim(),
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('画像を読み込めません',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textHint)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildLabel('リンクURL（任意）'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _linkUrlController,
              decoration: _inputDecoration('https://example.com'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            _buildLabel('開始日'),
            const SizedBox(height: 6),
            _buildDateRow(
              label: _formatDate(_startDate),
              onTap: () => _pickDate(isStart: true),
              onClear:
                  _startDate != null ? () => setState(() => _startDate = null) : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('終了日'),
            const SizedBox(height: 6),
            _buildDateRow(
              label: _formatDate(_endDate),
              onTap: () => _pickDate(isStart: false),
              onClear:
                  _endDate != null ? () => setState(() => _endDate = null) : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('表示画面'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _targetScreen,
                  isExpanded: true,
                  items: _targetScreens
                      .map((t) => DropdownMenuItem(
                          value: t['value'], child: Text(t['label']!)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _targetScreen = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('アクティブ'),
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

  Widget _buildDateRow({
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: AppTheme.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    color: label == '未設定'
                        ? AppTheme.textHint
                        : AppTheme.textPrimary,
                  )),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child:
                    Icon(Icons.clear, size: 18, color: AppTheme.textHint),
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
