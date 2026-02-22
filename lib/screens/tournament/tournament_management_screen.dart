import 'package:flutter/material.dart';
import 'tournament_detail_screen.dart';
import 'tournament_rules_screen.dart';
import 'venue_search_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen({super.key});
  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  static const _iconOptions = <String, IconData>{
    'emoji_events': Icons.emoji_events,
    'sports_volleyball': Icons.sports_volleyball,
    'sports': Icons.sports,
    'star': Icons.star,
    'bolt': Icons.bolt,
    'local_fire_department': Icons.local_fire_department,
    'diamond': Icons.diamond,
    'shield': Icons.shield,
    'flag': Icons.flag,
    'military_tech': Icons.military_tech,
    'workspace_premium': Icons.workspace_premium,
    'celebration': Icons.celebration,
  };

  IconData _getIcon(String? iconName) {
    if (iconName == null || !_iconOptions.containsKey(iconName)) return Icons.emoji_events;
    return _iconOptions[iconName]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(appBar: AppBar(title: const Text('大会管理')),
          body: const Center(child: Text('ログインしてください')));
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('大会管理')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tournaments')
            .where('organizerId', isEqualTo: _currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildTournamentCard(docs[index]));
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'template',
            onPressed: _showTemplatePickerSheet,
            backgroundColor: Colors.white,
            child: const Icon(Icons.description_outlined, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _showCreateTournamentSheet,
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('大会を作成', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.emoji_events_outlined, size: 80, color: AppTheme.textHint),
        const SizedBox(height: 16),
        const Text('まだ主催大会がありません', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('大会を作成して参加者を募集しましょう！', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildTournamentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '無名大会';
    final date = data['date'] ?? '';
    final location = data['location'] ?? '';
    final status = data['status'] ?? '準備中';
    final format = data['format'] ?? '';
    final entryFee = data['entryFee'] ?? '¥0';
    final currentTeams = data['currentTeams'] ?? 0;
    final maxTeams = data['maxTeams'] ?? 8;
    final courts = data['courts'] ?? 0;
    final type = data['type'] ?? '混合';
    Color statusColor;
    switch (status) {
      case '募集中': statusColor = AppTheme.success; break;
      case '準備中': statusColor = AppTheme.warning; break;
      case '開催中': statusColor = AppTheme.primaryColor; break;
      default: statusColor = AppTheme.textSecondary;
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentDetailScreen(tournament: {...data, 'id': doc.id, 'name': data['title'] ?? ''}))),
      child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: () => _showIconPicker(doc.id, data['icon'] as String?),
              child: CircleAvatar(radius: 20, backgroundColor: AppTheme.primaryColor.withValues(alpha:0.12),
                  child: Icon(_getIcon(data['icon'] as String?), color: AppTheme.primaryColor, size: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                _buildTag(status, statusColor), const SizedBox(width: 6),
                if (format.isNotEmpty) _buildTag(format, AppTheme.textSecondary),
                if (type.isNotEmpty) ...[const SizedBox(width: 6), _buildTag(type, AppTheme.primaryColor)],
              ]),
            ])),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
              onSelected: (value) {
                if (value == 'edit') _showEditTournamentSheet(doc.id, data);
                if (value == 'status') _showStatusDialog(doc.id, status);
                if (value == 'duplicate') _showCreateFromTemplate(data);
                if (value == 'save_template') _saveAsTemplate(data);
                if (value == 'delete') _showDeleteDialog(doc.id, title);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('編集')),
                const PopupMenuItem(value: 'status', child: Text('ステータス変更')),
                const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 18, color: AppTheme.textSecondary), SizedBox(width: 8), Text('この大会を複製')])),
                const PopupMenuItem(value: 'save_template', child: Row(children: [Icon(Icons.bookmark_add_outlined, size: 18, color: AppTheme.textSecondary), SizedBox(width: 8), Text('テンプレートに保存')])),
                const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _buildInfoChip(Icons.calendar_today_outlined, date), const SizedBox(width: 16),
            _buildInfoChip(Icons.location_on_outlined, location),
          ]),
          if (courts > 0) ...[const SizedBox(height: 6), _buildInfoChip(Icons.grid_view, '$courtsコート')],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('エントリー $currentTeams/$maxTeamsチーム', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: maxTeams > 0 ? currentTeams / maxTeams : 0,
                    backgroundColor: Colors.grey[200], color: AppTheme.primaryColor, minHeight: 6)),
            ])),
            const SizedBox(width: 16),
            Text(entryFee, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ]),
        ]),
      ),
    ));
  }

  void _showIconPicker(String docId, String? currentIcon) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('アイコンを変更', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _iconOptions.entries.map((entry) {
            final isSelected = (currentIcon ?? 'emoji_events') == entry.key;
            return GestureDetector(
              onTap: () async {
                await FirebaseFirestore.instance.collection('tournaments').doc(docId).update({'icon': entry.key});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
                ),
                child: Icon(entry.value, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary, size: 24),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Status / Delete dialogs
  // ══════════════════════════════════════

  void _showStatusDialog(String docId, String currentStatus) {
    final statuses = ['準備中', '募集中', '開催中', '終了'];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ステータス変更', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: statuses.map((s) {
        return RadioListTile<String>(title: Text(s), value: s, groupValue: currentStatus, activeColor: AppTheme.primaryColor,
          onChanged: (v) async {
            if (v != null) {
              await FirebaseFirestore.instance.collection('tournaments').doc(docId).update({'status': v});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ステータスを「$v」に変更しました'), backgroundColor: AppTheme.success));
            }
          });
      }).toList()),
    ));
  }

  void _showDeleteDialog(String docId, String title) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('大会を削除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: Text('「$title」を削除しますか？\nこの操作は取り消せません。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary))),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('tournaments').doc(docId).delete();
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「$title」を削除しました'), backgroundColor: AppTheme.error));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          child: const Text('削除する'),
        ),
      ],
    ));
  }

  // ══════════════════════════════════════
  //  Edit Tournament Sheet
  // ══════════════════════════════════════

  void _showEditTournamentSheet(String docId, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final locationCtrl = TextEditingController(text: data['location'] ?? '');
    final feeCtrl = TextEditingController(text: (data['entryFee'] ?? '').toString().replaceAll('¥', ''));
    final maxTeamsCtrl = TextEditingController(text: (data['maxTeams'] ?? 8).toString());
    final courtsCtrl = TextEditingController(text: (data['courts'] ?? 2).toString());
    String selectedType = data['type'] ?? '混合';
    String selectedDate = data['date'] ?? '';
    Map<String, dynamic>? tournamentRules = (data['rules'] is Map) ? Map<String, dynamic>.from(data['rules']) : null;
    Map<String, dynamic>? selectedVenue;
    if (data['venueId'] != null && (data['venueId'] as String).isNotEmpty) {
      selectedVenue = {'id': data['venueId'], 'name': data['location'], 'address': data['venueAddress'] ?? ''};
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('大会を編集', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('大会名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, maxLength: 30, onChanged: (_) => setSheetState(() {}), decoration: _sheetInputDecoration('大会名を入力')),
              const SizedBox(height: 8),
              const Text('開催日 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setSheetState(() => selectedDate = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary), const SizedBox(width: 10),
                    Text(selectedDate.isEmpty ? '日付を選択' : selectedDate, style: TextStyle(fontSize: 15, color: selectedDate.isEmpty ? AppTheme.textHint : AppTheme.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text('会場 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(ctx, MaterialPageRoute(builder: (_) => const VenueSearchScreen(pickerMode: true)));
                  if (result != null) setSheetState(() { selectedVenue = result; locationCtrl.text = result['name'] ?? ''; courtsCtrl.text = (result['courts'] ?? courtsCtrl.text).toString(); });
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(selectedVenue != null ? Icons.check_circle : Icons.search, size: 18, color: selectedVenue != null ? AppTheme.success : AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(locationCtrl.text.isNotEmpty ? locationCtrl.text : '会場を探す',
                        style: TextStyle(fontSize: 15, color: locationCtrl.text.isNotEmpty ? AppTheme.textPrimary : AppTheme.textHint))),
                  ]),
                ),
              ),
              if (selectedVenue != null && (selectedVenue!['address'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(selectedVenue!['address'], style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('コート数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: courtsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('2')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('最大チーム数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: maxTeamsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('8')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('参加費(円)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('3000')),
                ])),
              ]),
              const SizedBox(height: 16),
              const Text('カテゴリ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['混合', 'メンズ', 'レディース'].map((t) {
                return ChoiceChip(label: Text(t), selected: selectedType == t,
                    onSelected: (s) { if (s) setSheetState(() => selectedType = t); },
                    selectedColor: AppTheme.primaryColor.withValues(alpha:0.15));
              }).toList()),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context,
                    MaterialPageRoute(builder: (_) => TournamentRulesScreen(initialRules: tournamentRules, courtCount: int.tryParse(courtsCtrl.text))));
                  if (result != null) setSheetState(() => tournamentRules = result);
                },
                icon: Icon(tournamentRules != null ? Icons.check_circle : Icons.tune, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                label: Text(tournamentRules != null ? 'ルール設定済み ✓' : 'ルールを設定する',
                    style: TextStyle(fontWeight: FontWeight.w600, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: titleCtrl.text.trim().isNotEmpty && selectedDate.isNotEmpty && locationCtrl.text.trim().isNotEmpty
                    ? () async {
                        await FirebaseFirestore.instance.collection('tournaments').doc(docId).update({
                          'title': titleCtrl.text.trim(), 'date': selectedDate, 'location': locationCtrl.text.trim(),
                          'courts': int.tryParse(courtsCtrl.text) ?? 2, 'maxTeams': int.tryParse(maxTeamsCtrl.text) ?? 8,
                          'entryFee': '¥${feeCtrl.text.trim()}', 'format': '4人制', 'type': selectedType,
                          'venueId': selectedVenue?['id'] ?? '', 'venueAddress': selectedVenue?['address'] ?? '',
                          'rules': tournamentRules ?? {},
                        });
                        if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('大会情報を更新しました！'), backgroundColor: AppTheme.success)); }
                      } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 8),
            ])),
          );
        });
      },
    );
  }

  // ══════════════════════════════════════
  //  Create Tournament Sheet
  // ══════════════════════════════════════

  void _showCreateTournamentSheet() {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '3000');
    final maxTeamsCtrl = TextEditingController(text: '8');
    final courtsCtrl = TextEditingController(text: '2');
    String selectedType = '混合';
    String selectedDate = '';
    Map<String, dynamic>? tournamentRules;
    Map<String, dynamic>? selectedVenue;
    String openTime = '8:00';
    String receptionTime = '8:30';
    String openingTime = '9:00';
    String matchStartTime = '9:15';
    String finalTime = '14:00';
    String closingTime = '16:00';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('新しい大会を作成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('大会名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, maxLength: 30, onChanged: (_) => setSheetState(() {}), decoration: _sheetInputDecoration('大会名を入力')),
              const SizedBox(height: 8),
              const Text('開催日 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setSheetState(() => selectedDate = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary), const SizedBox(width: 10),
                    Text(selectedDate.isEmpty ? '日付を選択' : selectedDate, style: TextStyle(fontSize: 15, color: selectedDate.isEmpty ? AppTheme.textHint : AppTheme.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text('会場 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(ctx, MaterialPageRoute(builder: (_) => const VenueSearchScreen(pickerMode: true)));
                  if (result != null) setSheetState(() { selectedVenue = result; locationCtrl.text = result['name'] ?? ''; courtsCtrl.text = (result['courts'] ?? courtsCtrl.text).toString(); });
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(selectedVenue != null ? Icons.check_circle : Icons.search, size: 18, color: selectedVenue != null ? AppTheme.success : AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(selectedVenue != null ? selectedVenue!['name'] ?? '' : '会場を探す',
                        style: TextStyle(fontSize: 15, color: selectedVenue != null ? AppTheme.textPrimary : AppTheme.textHint))),
                  ]),
                ),
              ),
              if (selectedVenue != null && (selectedVenue!['address'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(selectedVenue!['address'], style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('コート数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: courtsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('2')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('最大チーム数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: maxTeamsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('8')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('参加費(円)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('3000')),
                ])),
              ]),
              const SizedBox(height: 16),
              const Text('カテゴリ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['混合', 'メンズ', 'レディース'].map((t) {
                return ChoiceChip(label: Text(t), selected: selectedType == t,
                    onSelected: (s) { if (s) setSheetState(() => selectedType = t); },
                    selectedColor: AppTheme.primaryColor.withValues(alpha:0.15));
              }).toList()),
              const SizedBox(height: 24),
              // ── スケジュール設定 ──
              const Text('当日スケジュール', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _buildTimeRow('開場', openTime, (v) => setSheetState(() => openTime = v), ctx),
                  _buildTimeRow('受付', receptionTime, (v) => setSheetState(() => receptionTime = v), ctx),
                  _buildTimeRow('開会式', openingTime, (v) => setSheetState(() => openingTime = v), ctx),
                  _buildTimeRow('試合開始', matchStartTime, (v) => setSheetState(() => matchStartTime = v), ctx),
                  _buildTimeRow('決勝予定', finalTime, (v) => setSheetState(() => finalTime = v), ctx),
                  _buildTimeRow('閉会式', closingTime, (v) => setSheetState(() => closingTime = v), ctx),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context,
                    MaterialPageRoute(builder: (_) => TournamentRulesScreen(initialRules: tournamentRules, courtCount: int.tryParse(courtsCtrl.text))));
                  if (result != null) setSheetState(() => tournamentRules = result);
                },
                icon: Icon(tournamentRules != null ? Icons.check_circle : Icons.tune, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                label: Text(tournamentRules != null ? 'ルール設定済み ✓' : 'ルールを設定する',
                    style: TextStyle(fontWeight: FontWeight.w600, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: titleCtrl.text.trim().isNotEmpty && selectedDate.isNotEmpty && locationCtrl.text.trim().isNotEmpty
                    ? () async {
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
                        final nickname = (userDoc.data()?['nickname'] ?? '不明').toString();
                        await FirebaseFirestore.instance.collection('tournaments').add({
                          'title': titleCtrl.text.trim(), 'date': selectedDate, 'location': locationCtrl.text.trim(),
                          'venueId': selectedVenue?['id'] ?? '', 'venueAddress': selectedVenue?['address'] ?? '',
                          'courts': int.tryParse(courtsCtrl.text) ?? 2, 'maxTeams': int.tryParse(maxTeamsCtrl.text) ?? 8,
                          'currentTeams': 0, 'entryFee': '¥${feeCtrl.text.trim()}', 'format': '4人制', 'type': selectedType,
                          'status': '募集中', 'organizerId': _currentUser!.uid, 'organizerName': nickname,
                          'openTime': openTime, 'receptionTime': receptionTime, 'openingTime': openingTime,
                          'matchStartTime': matchStartTime, 'finalTime': finalTime, 'closingTime': closingTime,
                          'entryTeamIds': [], 'rules': tournamentRules ?? {}, 'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('「${titleCtrl.text.trim()}」を作成しました！'), backgroundColor: AppTheme.success)); }
                      } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('大会を作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 8),
            ])),
          );
        });
      },
    );
  }

  // ══════════════════════════════════════
  //  Template: テンプレートから作成
  // ══════════════════════════════════════

  void _showTemplatePickerSheet() {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('テンプレートから作成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('保存したテンプレートを使って大会を作成できます', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(uid).collection('templates')
                  .orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                final templates = snap.data!.docs;
                if (templates.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Icon(Icons.description_outlined, size: 40, color: AppTheme.textHint),
                      const SizedBox(height: 8),
                      const Text('テンプレートがありません', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('大会カードのメニューから「テンプレートに保存」できます', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ]),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tData = templates[index].data() as Map<String, dynamic>;
                      final name = tData['name'] ?? 'テンプレート';
                      final type = tData['type'] ?? '';
                      final maxTeams = tData['maxTeams'] ?? 8;
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.description_outlined, color: AppTheme.primaryColor, size: 20),
                        ),
                        title: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$type  $maxTeamsチーム', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCreateFromTemplate(tData);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }

  /// 大会データからテンプレート保存
  Future<void> _saveAsTemplate(Map<String, dynamic> data) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final title = data['title'] ?? '大会';
    final rules = data['rules'] as Map<String, dynamic>? ?? {};
    final preliminary = rules['preliminary'] as Map<String, dynamic>? ?? {};

    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('templates').add({
      'name': '$titleのテンプレート',
      'type': data['type'] ?? '混合',
      'format': data['format'] ?? '4人制',
      'maxTeams': data['maxTeams'] ?? 8,
      'setCount': (preliminary['sets'] ?? '3').toString(),
      'pointsPerSet': (preliminary['pointsPerSet'] ?? '25').toString(),
      'location': data['location'] ?? '',
      'memo': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートに保存しました'), backgroundColor: AppTheme.success),
      );
    }
  }

  /// テンプレート or 既存大会データから新しい大会を作成
  void _showCreateFromTemplate(Map<String, dynamic> templateData) {
    final titleCtrl = TextEditingController(text: '');
    final locationCtrl = TextEditingController(text: (templateData['location'] ?? '') as String);
    final feeCtrl = TextEditingController(text: (templateData['entryFee'] ?? '3000').toString().replaceAll('¥', ''));
    final maxTeamsCtrl = TextEditingController(text: (templateData['maxTeams'] ?? 8).toString());
    final courtsCtrl = TextEditingController(text: (templateData['courts'] ?? 2).toString());
    String selectedType = (templateData['type'] ?? '混合') as String;
    String selectedDate = '';
    Map<String, dynamic>? tournamentRules = (templateData['rules'] is Map) ? Map<String, dynamic>.from(templateData['rules']) : null;
    Map<String, dynamic>? selectedVenue;
    if (templateData['venueId'] != null && (templateData['venueId'] as String).isNotEmpty) {
      selectedVenue = {'id': templateData['venueId'], 'name': templateData['location'], 'address': templateData['venueAddress'] ?? ''};
    }
    String openTime = (templateData['openTime'] ?? '8:00') as String;
    String receptionTime = (templateData['receptionTime'] ?? '8:30') as String;
    String openingTime = (templateData['openingTime'] ?? '9:00') as String;
    String matchStartTime = (templateData['matchStartTime'] ?? '9:15') as String;
    String finalTime = (templateData['finalTime'] ?? '14:00') as String;
    String closingTime = (templateData['closingTime'] ?? '16:00') as String;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.copy, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('テンプレートから大会を作成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              const Text('大会名 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, maxLength: 30, onChanged: (_) => setSheetState(() {}), decoration: _sheetInputDecoration('大会名を入力')),
              const SizedBox(height: 8),
              const Text('開催日 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setSheetState(() => selectedDate = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary), const SizedBox(width: 10),
                    Text(selectedDate.isEmpty ? '日付を選択' : selectedDate, style: TextStyle(fontSize: 15, color: selectedDate.isEmpty ? AppTheme.textHint : AppTheme.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text('会場 *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(ctx, MaterialPageRoute(builder: (_) => const VenueSearchScreen(pickerMode: true)));
                  if (result != null) setSheetState(() { selectedVenue = result; locationCtrl.text = result['name'] ?? ''; courtsCtrl.text = (result['courts'] ?? courtsCtrl.text).toString(); });
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(locationCtrl.text.isNotEmpty ? Icons.check_circle : Icons.search, size: 18, color: locationCtrl.text.isNotEmpty ? AppTheme.success : AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(locationCtrl.text.isNotEmpty ? locationCtrl.text : '会場を探す',
                        style: TextStyle(fontSize: 15, color: locationCtrl.text.isNotEmpty ? AppTheme.textPrimary : AppTheme.textHint))),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('コート数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: courtsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('2')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('最大チーム数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: maxTeamsCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('8')),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('参加費(円)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                  TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: _sheetInputDecoration('3000')),
                ])),
              ]),
              const SizedBox(height: 16),
              const Text('カテゴリ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['混合', 'メンズ', 'レディース'].map((t) {
                return ChoiceChip(label: Text(t), selected: selectedType == t,
                    onSelected: (s) { if (s) setSheetState(() => selectedType = t); },
                    selectedColor: AppTheme.primaryColor.withValues(alpha:0.15));
              }).toList()),
              const SizedBox(height: 24),
              const Text('当日スケジュール', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _buildTimeRow('開場', openTime, (v) => setSheetState(() => openTime = v), ctx),
                  _buildTimeRow('受付', receptionTime, (v) => setSheetState(() => receptionTime = v), ctx),
                  _buildTimeRow('開会式', openingTime, (v) => setSheetState(() => openingTime = v), ctx),
                  _buildTimeRow('試合開始', matchStartTime, (v) => setSheetState(() => matchStartTime = v), ctx),
                  _buildTimeRow('決勝予定', finalTime, (v) => setSheetState(() => finalTime = v), ctx),
                  _buildTimeRow('閉会式', closingTime, (v) => setSheetState(() => closingTime = v), ctx),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context,
                    MaterialPageRoute(builder: (_) => TournamentRulesScreen(initialRules: tournamentRules, courtCount: int.tryParse(courtsCtrl.text))));
                  if (result != null) setSheetState(() => tournamentRules = result);
                },
                icon: Icon(tournamentRules != null ? Icons.check_circle : Icons.tune, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                label: Text(tournamentRules != null ? 'ルール設定済み' : 'ルールを設定する',
                    style: TextStyle(fontWeight: FontWeight.w600, color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tournamentRules != null ? AppTheme.success : AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: titleCtrl.text.trim().isNotEmpty && selectedDate.isNotEmpty
                    ? () async {
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
                        final nickname = (userDoc.data()?['nickname'] ?? '不明').toString();
                        await FirebaseFirestore.instance.collection('tournaments').add({
                          'title': titleCtrl.text.trim(), 'date': selectedDate, 'location': locationCtrl.text.trim(),
                          'venueId': selectedVenue?['id'] ?? '', 'venueAddress': selectedVenue?['address'] ?? '',
                          'courts': int.tryParse(courtsCtrl.text) ?? 2, 'maxTeams': int.tryParse(maxTeamsCtrl.text) ?? 8,
                          'currentTeams': 0, 'entryFee': '¥${feeCtrl.text.trim()}', 'format': '4人制', 'type': selectedType,
                          'status': '募集中', 'organizerId': _currentUser!.uid, 'organizerName': nickname,
                          'openTime': openTime, 'receptionTime': receptionTime, 'openingTime': openingTime,
                          'matchStartTime': matchStartTime, 'finalTime': finalTime, 'closingTime': closingTime,
                          'entryTeamIds': [], 'rules': tournamentRules ?? {}, 'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('「${titleCtrl.text.trim()}」を作成しました！'), backgroundColor: AppTheme.success)); }
                      } : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('大会を作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 8),
            ])),
          );
        });
      },
    );
  }

  // ══════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════

  InputDecoration _sheetInputDecoration(String hint) {
    return InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint),
      filled: true, fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));
  }

  Widget _buildTag(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)));
  }

  Widget _buildTimeRow(String label, String value, Function(String) onChanged, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final parts = value.split(':');
              final h = int.tryParse(parts[0]) ?? 8;
              final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
              final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: h, minute: m));
              if (picked != null) {
                onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }

  

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary), const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    ]);
  }
}
