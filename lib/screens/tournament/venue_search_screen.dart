import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';

class VenueSearchScreen extends StatefulWidget {
  const VenueSearchScreen({super.key});
  @override
  State<VenueSearchScreen> createState() => _VenueSearchScreenState();
}

class _VenueSearchScreenState extends State<VenueSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('会場を探す', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.add_location_alt),
            onPressed: () async {
              final result = await Navigator.push<bool>(context,
                MaterialPageRoute(builder: (_) => const VenueRegisterScreen()));
              if (result == true) setState(() {});
            }),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: '会場名・住所で検索',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true, fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        // 参加者への案内
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '会場情報は誰でも追加・編集できます。大会に参加して気づいたことがあれば更新してください！',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('venues').orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              final filtered = _query.isEmpty ? docs : docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final address = (data['address'] ?? '').toString().toLowerCase();
                return name.contains(_query) || address.contains(_query);
              }).toList();
              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('会場が見つかりません', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => const VenueRegisterScreen()));
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新しい会場を登録'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  ),
                ]));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final data = filtered[index].data() as Map<String, dynamic>;
                  return _buildVenueCard(data, filtered[index].id);
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> data, String docId) {
    final name = data['name'] ?? '';
    final address = data['address'] ?? '';
    final phone = data['phone'] ?? '';
    final parking = data['parking'] ?? 0;
    final toilets = data['toilets'] ?? 0;
    final courts = data['courts'] ?? 0;
    final hasAC = data['hasAC'] ?? false;
    final hasChangeRoom = data['hasChangeRoom'] ?? false;
    final rating = (data['rating'] ?? 0).toDouble();
    final reviewCount = data['reviewCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, {
          'id': docId, 'name': name, 'address': address,
          'phone': phone, 'parking': parking, 'toilets': toilets,
          'courts': courts,
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (rating > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(' ${rating.toStringAsFixed(1)} ($reviewCount)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(width: 8),
              // 編集ボタン
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<bool>(context,
                    MaterialPageRoute(builder: (_) => VenueRegisterScreen(
                      existingVenue: data, venueId: docId)));
                  if (result == true) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryColor),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(address, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 6, children: [
              if (courts > 0) _chip(Icons.grid_view, '$courtsコート'),
              if (phone.isNotEmpty) _chip(Icons.phone, phone),
              if (parking > 0) _chip(Icons.local_parking, '$parking台'),
              if (toilets > 0) _chip(Icons.wc, '$toilets箇所'),
              if (hasAC) _chip(Icons.ac_unit, '空調あり'),
              if (hasChangeRoom) _chip(Icons.checkroom, '更衣室あり'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppTheme.primaryColor),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

class VenueRegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? existingVenue;
  final String? venueId;
  const VenueRegisterScreen({super.key, this.existingVenue, this.venueId});
  @override
  State<VenueRegisterScreen> createState() => _VenueRegisterScreenState();
}

class _VenueRegisterScreenState extends State<VenueRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _courtsCtrl = TextEditingController();
  final _parkingCtrl = TextEditingController();
  final _toiletsCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController(text: '8:00');
  final _closeTimeCtrl = TextEditingController(text: '22:00');
  final _feeCtrl = TextEditingController();
  final _eatAreaCtrl = TextEditingController();
  bool _hasChangeRoom = false;
  bool _hasShower = false;
  bool _hasGallery = false;
  bool _hasAC = false;

  final List<Map<String, dynamic>> _equipments = [];
  final _eqNameCtrl = TextEditingController();
  final _eqQtyCtrl = TextEditingController();
  final _eqFeeCtrl = TextEditingController(text: '0');

  bool _saving = false;
  bool get _isEditing => widget.venueId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingVenue != null) {
      final v = widget.existingVenue!;
      _nameCtrl.text = (v['name'] as String?) ?? '';
      _addressCtrl.text = (v['address'] as String?) ?? '';
      _phoneCtrl.text = (v['phone'] as String?) ?? '';
      _courtsCtrl.text = (v['courts'] ?? 0) > 0 ? '${v['courts']}' : '';
      _parkingCtrl.text = (v['parking'] ?? 0) > 0 ? '${v['parking']}' : '';
      _toiletsCtrl.text = (v['toilets'] ?? 0) > 0 ? '${v['toilets']}' : '';
      _stationCtrl.text = (v['station'] as String?) ?? '';
      _openTimeCtrl.text = (v['openTime'] as String?) ?? '8:00';
      _closeTimeCtrl.text = (v['closeTime'] as String?) ?? '22:00';
      _feeCtrl.text = (v['fee'] as String?) ?? '';
      _eatAreaCtrl.text = (v['eatArea'] as String?) ?? '';
      _hasChangeRoom = v['hasChangeRoom'] ?? false;
      _hasShower = v['hasShower'] ?? false;
      _hasGallery = v['hasGallery'] ?? false;
      _hasAC = v['hasAC'] ?? false;
      if (v['equipments'] is List) {
        for (final eq in v['equipments']) {
          if (eq is Map<String, dynamic>) {
            _equipments.add(Map<String, dynamic>.from(eq));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameCtrl.text.trim().isNotEmpty && _addressCtrl.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? '会場を編集' : '会場を登録',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_isEditing)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '会場情報を更新します。実際に利用して気づいた情報を追加してください。',
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          _section('基本情報', Icons.info_outline),
          const SizedBox(height: 12),
          _label('会場名 *'),
          _field(_nameCtrl, '例: 森町総合体育館'),
          _label('住所 *'),
          _field(_addressCtrl, '例: 静岡県周智郡森町森92-8'),
          _label('電話番号'),
          _field(_phoneCtrl, '例: 0538-85-4191', keyboard: TextInputType.phone),
          _label('最寄り駅・バス停'),
          _field(_stationCtrl, '例: JR森駅 徒歩10分'),

          const SizedBox(height: 20),
          _section('施設情報', Icons.apartment),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('コート数(最大)'), _field(_courtsCtrl, '例: 4', keyboard: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('駐車場(台数)'), _field(_parkingCtrl, '例: 100', keyboard: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('トイレ(箇所)'), _field(_toiletsCtrl, '例: 3', keyboard: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 8),
          _switchRow('更衣室', _hasChangeRoom, (v) => setState(() => _hasChangeRoom = v)),
          _switchRow('シャワー', _hasShower, (v) => setState(() => _hasShower = v)),
          _switchRow('観覧席/ギャラリー', _hasGallery, (v) => setState(() => _hasGallery = v)),
          _switchRow('空調', _hasAC, (v) => setState(() => _hasAC = v)),
          const SizedBox(height: 8),
          _label('飲食可能エリア'),
          _field(_eatAreaCtrl, '例: 2階控室のみ可、フロア内は水分補給のみ'),

          const SizedBox(height: 20),
          _section('利用情報', Icons.access_time),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('利用開始時間'), _field(_openTimeCtrl, '8:00'),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('利用終了時間'), _field(_closeTimeCtrl, '22:00'),
            ])),
          ]),
          _label('利用料金(目安)'),
          _field(_feeCtrl, '例: 1時間¥2,000 / 終日¥15,000'),

          const SizedBox(height: 20),
          _section('貸出備品', Icons.inventory_2),
          const SizedBox(height: 12),
          ..._equipments.asMap().entries.map((e) => _equipmentRow(e.key, e.value)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _eqNameCtrl,
              decoration: _inputDeco('備品名'), style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: TextField(controller: _eqQtyCtrl,
              decoration: _inputDeco('数量'), keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: TextField(controller: _eqFeeCtrl,
              decoration: _inputDeco('料金(円)'), keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_eqNameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _equipments.add({
                    'name': _eqNameCtrl.text.trim(),
                    'qty': int.tryParse(_eqQtyCtrl.text) ?? 1,
                    'fee': int.tryParse(_eqFeeCtrl.text) ?? 0,
                  });
                  _eqNameCtrl.clear(); _eqQtyCtrl.clear(); _eqFeeCtrl.text = '0';
                });
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ]),

          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: canSave && !_saving ? _saveVenue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEditing ? '会場を更新する' : '会場を登録する',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _saveVenue() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final venueData = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'station': _stationCtrl.text.trim(),
        'courts': int.tryParse(_courtsCtrl.text) ?? 0,
        'parking': int.tryParse(_parkingCtrl.text) ?? 0,
        'toilets': int.tryParse(_toiletsCtrl.text) ?? 0,
        'hasChangeRoom': _hasChangeRoom,
        'hasShower': _hasShower,
        'hasGallery': _hasGallery,
        'hasAC': _hasAC,
        'eatArea': _eatAreaCtrl.text.trim(),
        'openTime': _openTimeCtrl.text.trim(),
        'closeTime': _closeTimeCtrl.text.trim(),
        'fee': _feeCtrl.text.trim(),
        'equipments': _equipments,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': user?.uid ?? '',
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('venues')
            .doc(widget.venueId)
            .update(venueData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('会場情報を更新しました！'), backgroundColor: AppTheme.success));
          Navigator.pop(context, true);
        }
      } else {
        venueData['rating'] = 0;
        venueData['reviewCount'] = 0;
        venueData['registeredBy'] = user?.uid ?? '';
        venueData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('venues').add(venueData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('会場を登録しました！'), backgroundColor: AppTheme.success));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      ]),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: (_) => setState(() {}),
      decoration: _inputDeco(hint),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
      filled: true, fillColor: AppTheme.backgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primaryColor),
      ]),
    );
  }

  Widget _equipmentRow(int index, Map<String, dynamic> eq) {
    final fee = eq['fee'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text(eq['name'], style: const TextStyle(fontSize: 14))),
        Expanded(flex: 2, child: Text('${eq['qty']}個', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary))),
        Expanded(flex: 2, child: Text(fee == 0 ? '無料' : '¥$fee',
          style: TextStyle(fontSize: 14, color: fee == 0 ? AppTheme.success : AppTheme.textPrimary))),
        GestureDetector(
          onTap: () => setState(() => _equipments.removeAt(index)),
          child: const Icon(Icons.close, size: 18, color: Colors.red),
        ),
      ]),
    );
  }
}
