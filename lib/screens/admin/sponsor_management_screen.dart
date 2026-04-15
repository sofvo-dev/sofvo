import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../widgets/sponsor_banner.dart'
    show normalizeSponsorImageUrl, sponsorImageHeightFor;

/// スポンサー管理画面（公式アカウント用）
class SponsorManagementScreen extends StatelessWidget {
  const SponsorManagementScreen({super.key});

  /// startDate / endDate と active フラグからステータスを判定
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
      case '無効':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String _placementLabel(String? placement) {
    switch (placement) {
      case 'home_top':
        return 'ホーム上部';
      case 'home_bottom':
        return 'ホーム下部';
      case 'tournament_list':
        return '大会一覧';
      case 'chat_list':
        return 'チャット一覧';
      case 'all':
        return '全画面';
      default:
        return placement ?? '-';
    }
  }

  static String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('スポンサー管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _showSponsorForm(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // orderBy('order') は order フィールドが無いドキュメントを除外してしまうため使わない。
        // 代わりにクライアント側でソートする。
        stream: FirebaseFirestore.instance.collection('sponsors').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final docs = (snapshot.data?.docs ?? []).toList()
            ..sort((a, b) {
              final da = a.data() as Map<String, dynamic>;
              final db = b.data() as Map<String, dynamic>;
              final oa = (da['order'] as num?)?.toInt() ?? 0;
              final ob = (db['order'] as num?)?.toInt() ?? 0;
              return oa.compareTo(ob);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('スポンサーはありません',
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
              return _SponsorCard(
                docId: doc.id,
                data: data,
                onEdit: () =>
                    _showSponsorForm(context, docId: doc.id, data: data),
                onToggleActive: () => _toggleActive(doc.id, data),
                onDelete: () => _confirmDelete(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleActive(String docId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('sponsors')
        .doc(docId)
        .update({'active': !(data['active'] == true)});
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('スポンサーを削除'),
        content:
            Text('「${data['name'] ?? ''}」を削除しますか？この操作は取り消せません。'),
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
          .collection('sponsors')
          .doc(docId)
          .delete();
    }
  }

  void _showSponsorForm(BuildContext context,
      {String? docId, Map<String, dynamic>? data}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SponsorFormScreen(docId: docId, initialData: data),
      ),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SponsorCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final linkUrl = data['linkUrl'] as String? ?? '';
    final order = data['order'] as int? ?? 0;
    final active = data['active'] == true;
    final placement = data['placement'] as String?;
    final startDate = data['startDate'] as Timestamp?;
    final endDate = data['endDate'] as Timestamp?;
    final impressionCount = (data['impressionCount'] as num?)?.toInt() ?? 0;
    final clickCount = (data['clickCount'] as num?)?.toInt() ?? 0;
    final priority = (data['priority'] as num?)?.toInt() ?? 0;
    final status = SponsorManagementScreen._statusLabel(data);
    final statusColor = SponsorManagementScreen._statusColor(status);
    final ctr = impressionCount > 0
        ? (clickCount / impressionCount * 100).toStringAsFixed(1)
        : '0.0';

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
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                    ),
                    if (placement != null && placement.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          SponsorManagementScreen._placementLabel(placement),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: (_) => onToggleActive(),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (imageUrl.isNotEmpty) ...[
                  Builder(builder: (_) {
                    final previewHeight =
                        sponsorImageHeightFor(placement ?? 'all');
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        normalizeSponsorImageUrl(imageUrl),
                        height: previewHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: previewHeight,
                          color: Colors.grey[100],
                          child: Center(
                            child: Icon(Icons.broken_image,
                                color: AppTheme.textHint),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                // Analytics row
                Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 3),
                    Text('$impressionCount',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(width: 10),
                    Icon(Icons.touch_app, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 3),
                    Text('$clickCount',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(width: 10),
                    Icon(Icons.percent, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 3),
                    Text('CTR $ctr%',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.link, size: 14, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(linkUrl,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (priority > 0) ...[
                      Icon(Icons.priority_high,
                          size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 2),
                      Text('$priority',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                    ],
                    Text('表示順: $order',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                // Date range if set
                if (startDate != null || endDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.date_range,
                          size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '${SponsorManagementScreen._formatDate(startDate).isNotEmpty ? SponsorManagementScreen._formatDate(startDate) : '開始なし'}'
                        ' ~ '
                        '${SponsorManagementScreen._formatDate(endDate).isNotEmpty ? SponsorManagementScreen._formatDate(endDate) : '終了なし'}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SponsorFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const _SponsorFormScreen({this.docId, this.initialData});

  @override
  State<_SponsorFormScreen> createState() => _SponsorFormScreenState();
}

class _SponsorFormScreenState extends State<_SponsorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _linkUrlController;
  late final TextEditingController _orderController;
  late final TextEditingController _priorityController;
  late final TextEditingController _commentController;
  late final TextEditingController _targetAreasController;
  late final TextEditingController _minAgeController;
  late final TextEditingController _maxAgeController;
  late bool _active;
  late String _placement;
  DateTime? _startDate;
  DateTime? _endDate;
  // ターゲット性別（空リスト = 全性別対象）
  final Set<String> _targetGenders = {};
  bool _saving = false;

  // Read-only analytics
  int _impressionCount = 0;
  int _clickCount = 0;

  bool get _isEditing => widget.docId != null;

  static const _placements = [
    {'value': 'home_top', 'label': 'ホーム上部'},
    {'value': 'home_bottom', 'label': 'ホーム下部'},
    {'value': 'tournament_list', 'label': '大会一覧'},
    {'value': 'chat_list', 'label': 'チャット一覧'},
    {'value': 'all', 'label': '全画面'},
  ];

  static const _genderOptions = ['男性', '女性', 'その他'];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d?['name'] as String? ?? '');
    _imageUrlController =
        TextEditingController(text: d?['imageUrl'] as String? ?? '');
    _linkUrlController =
        TextEditingController(text: d?['linkUrl'] as String? ?? '');
    _orderController =
        TextEditingController(text: '${d?['order'] as int? ?? 0}');
    _priorityController =
        TextEditingController(text: '${(d?['priority'] as num?)?.toInt() ?? 5}');
    _commentController =
        TextEditingController(text: d?['comment'] as String? ?? '');

    final initAreas =
        (d?['targetAreas'] as List?)?.cast<String>() ?? const <String>[];
    _targetAreasController =
        TextEditingController(text: initAreas.join(', '));

    final minAge = (d?['minAge'] as num?)?.toInt();
    final maxAge = (d?['maxAge'] as num?)?.toInt();
    _minAgeController =
        TextEditingController(text: minAge != null ? '$minAge' : '');
    _maxAgeController =
        TextEditingController(text: maxAge != null ? '$maxAge' : '');

    final initGenders =
        (d?['targetGenders'] as List?)?.cast<String>() ?? const <String>[];
    _targetGenders.addAll(initGenders);

    _active = d?['active'] == true;
    _placement = d?['placement'] as String? ?? 'home_top';
    _startDate = (d?['startDate'] as Timestamp?)?.toDate();
    _endDate = (d?['endDate'] as Timestamp?)?.toDate();
    _impressionCount = (d?['impressionCount'] as num?)?.toInt() ?? 0;
    _clickCount = (d?['clickCount'] as num?)?.toInt() ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _linkUrlController.dispose();
    _orderController.dispose();
    _priorityController.dispose();
    _commentController.dispose();
    _targetAreasController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
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

    // エリアはカンマ区切りで入力 → リストに変換
    final targetAreas = _targetAreasController.text
        .split(RegExp(r'[、,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(_maxAgeController.text.trim());

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'linkUrl': _linkUrlController.text.trim(),
      'comment': _commentController.text.trim(),
      'order': int.tryParse(_orderController.text.trim()) ?? 0,
      'active': _active,
      'placement': _placement,
      'priority': int.tryParse(_priorityController.text.trim()) ?? 5,
      'startDate':
          _startDate != null ? Timestamp.fromDate(_startDate!) : null,
      'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
      // セグメント（空 = 全員対象）
      'targetAreas': targetAreas,
      'targetGenders': _targetGenders.toList(),
      'minAge': minAge,
      'maxAge': maxAge,
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('sponsors')
            .doc(widget.docId)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['impressionCount'] = 0;
        data['clickCount'] = 0;
        await FirebaseFirestore.instance.collection('sponsors').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctr = _impressionCount > 0
        ? (_clickCount / _impressionCount * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'スポンサー編集' : 'スポンサー追加',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
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
            // Analytics section (read-only, only in edit mode)
            if (_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('パフォーマンス',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildAnalyticsTile(
                            'インプレッション', '$_impressionCount', Icons.visibility),
                        const SizedBox(width: 12),
                        _buildAnalyticsTile(
                            'クリック数', '$_clickCount', Icons.touch_app),
                        const SizedBox(width: 12),
                        _buildAnalyticsTile('CTR', '$ctr%', Icons.percent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildLabel('企業名'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              decoration: _inputDecoration('企業名を入力'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '企業名を入力してください' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('バナー画像URL'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _imageUrlController,
              decoration: _inputDecoration('https://example.com/banner.png'),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '画像URLを入力してください' : null,
            ),
            const SizedBox(height: 4),
            Text(
              'Googleドライブ共有URLも貼り付けOK（自動で直リンク化されます）',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
            if (_imageUrlController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              // プレビュー高さは選択中の表示位置に合わせる
              Builder(builder: (_) {
                final previewHeight = sponsorImageHeightFor(_placement);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        normalizeSponsorImageUrl(
                            _imageUrlController.text.trim()),
                        height: previewHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: previewHeight,
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
                    const SizedBox(height: 4),
                    Text(
                      '※ この位置での表示高さ: ${previewHeight.toInt()}px',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textHint),
                    ),
                  ],
                );
              }),
            ],
            const SizedBox(height: 20),
            _buildLabel('コメント（任意・画像下に表示）'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _commentController,
              maxLength: 40,
              decoration: _inputDecoration('例: 新商品キャンペーン実施中！'),
            ),
            const SizedBox(height: 20),
            _buildLabel('リンクURL'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _linkUrlController,
              decoration: _inputDecoration('https://example.com'),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'リンクURLを入力してください' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('表示位置'),
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
                  value: _placement,
                  isExpanded: true,
                  items: _placements
                      .map((p) => DropdownMenuItem(
                          value: p['value'], child: Text(p['label']!)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _placement = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ━━━ セグメント設定 ━━━
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.people_alt_outlined,
                          size: 18, color: AppTheme.accentColor),
                      SizedBox(width: 6),
                      Text('配信セグメント（任意）',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('空欄の場合は全ユーザーに表示されます',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildLabel('対象エリア（カンマ区切り・都道府県名）'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _targetAreasController,
                    decoration: _inputDecoration('例: 東京都, 神奈川県, 千葉県'),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('対象性別'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _genderOptions.map((g) {
                      final selected = _targetGenders.contains(g);
                      return FilterChip(
                        label: Text(g),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _targetGenders.add(g);
                            } else {
                              _targetGenders.remove(g);
                            }
                          });
                        },
                        selectedColor:
                            AppTheme.accentColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.accentColor,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('対象年齢'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minAgeController,
                          decoration: _inputDecoration('下限'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('〜'),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _maxAgeController,
                          decoration: _inputDecoration('上限'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('表示開始日（任意）'),
            const SizedBox(height: 6),
            _buildDateRow(
              label: _formatDate(_startDate),
              onTap: () => _pickDate(isStart: true),
              onClear: _startDate != null
                  ? () => setState(() => _startDate = null)
                  : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('表示終了日（任意）'),
            const SizedBox(height: 6),
            _buildDateRow(
              label: _formatDate(_endDate),
              onTap: () => _pickDate(isStart: false),
              onClear: _endDate != null
                  ? () => setState(() => _endDate = null)
                  : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('優先度（1-10、高い方が優先表示）'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priorityController,
              decoration: _inputDecoration('5'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 10) return '1〜10の数値を入力してください';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('表示順'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _orderController,
              decoration: _inputDecoration('0'),
              keyboardType: TextInputType.number,
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

  Widget _buildAnalyticsTile(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
