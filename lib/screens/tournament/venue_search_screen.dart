import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_theme.dart';

class VenueSearchScreen extends StatefulWidget {
  final bool pickerMode;
  const VenueSearchScreen({super.key, this.pickerMode = false});
  @override
  State<VenueSearchScreen> createState() => _VenueSearchScreenState();
}

class _VenueSearchScreenState extends State<VenueSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterArea = 'すべて';
  String _sortBy = 'name'; // 'name', 'address', 'rating', 'courts'

  @override
  void initState() {
    super.initState();
    _loadUserArea();
  }

  Future<void> _loadUserArea() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final rawArea = doc.data()?['area'];
    final prefecture = rawArea is String ? rawArea : (rawArea is Map ? rawArea['prefecture'] ?? '' : '');
    if (prefecture.toString().isNotEmpty) {
      // 都道府県名からエリアを特定
      for (final entry in _prefectureToArea.entries) {
        if (prefecture.toString().contains(entry.key)) {
          if (mounted) setState(() => _filterArea = entry.value);
          break;
        }
      }
    }
  }

  static const _areas = [
    'すべて', '北海道', '東北', '関東', '中部', '近畿', '中国', '四国', '九州・沖縄',
  ];

  // 都道府県 → エリア のマッピング
  static const _prefectureToArea = {
    '北海道': '北海道',
    '青森': '東北', '岩手': '東北', '宮城': '東北', '秋田': '東北', '山形': '東北', '福島': '東北',
    '茨城': '関東', '栃木': '関東', '群馬': '関東', '埼玉': '関東', '千葉': '関東', '東京': '関東', '神奈川': '関東',
    '新潟': '中部', '富山': '中部', '石川': '中部', '福井': '中部', '山梨': '中部', '長野': '中部', '岐阜': '中部', '静岡': '中部', '愛知': '中部',
    '三重': '近畿', '滋賀': '近畿', '京都': '近畿', '大阪': '近畿', '兵庫': '近畿', '奈良': '近畿', '和歌山': '近畿',
    '鳥取': '中国', '島根': '中国', '岡山': '中国', '広島': '中国', '山口': '中国',
    '徳島': '四国', '香川': '四国', '愛媛': '四国', '高知': '四国',
    '福岡': '九州・沖縄', '佐賀': '九州・沖縄', '長崎': '九州・沖縄', '熊本': '九州・沖縄', '大分': '九州・沖縄', '宮崎': '九州・沖縄', '鹿児島': '九州・沖縄', '沖縄': '九州・沖縄',
  };

  bool _matchesArea(String address) {
    if (_filterArea == 'すべて') return true;
    for (final entry in _prefectureToArea.entries) {
      if (address.contains(entry.key) && entry.value == _filterArea) return true;
    }
    return false;
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        )),
      ),
    );
  }

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
        // エリアフィルタ
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _areas.length,
            itemBuilder: (context, index) {
              final area = _areas[index];
              final isSelected = _filterArea == area;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(area, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _filterArea = area),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 並び替え
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.sort, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text('並び替え:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            _buildSortChip('会場名', 'name'),
            const SizedBox(width: 6),
            _buildSortChip('住所', 'address'),
            const SizedBox(width: 6),
            _buildSortChip('評価', 'rating'),
            const SizedBox(width: 6),
            _buildSortChip('コート数', 'courts'),
          ]),
        ),
        const SizedBox(height: 8),
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
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final address = (data['address'] ?? '').toString().toLowerCase();
                final addressOriginal = (data['address'] ?? '').toString();
                if (_query.isNotEmpty && !name.contains(_query) && !address.contains(_query)) return false;
                if (!_matchesArea(addressOriginal)) return false;
                return true;
              }).toList();
              // Dart側ソート
              filtered.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;
                switch (_sortBy) {
                  case 'address':
                    return (da['address'] ?? '').toString().compareTo((db['address'] ?? '').toString());
                  case 'rating':
                    final ra = (da['rating'] is num ? (da['rating'] as num).toDouble() : 0.0);
                    final rb = (db['rating'] is num ? (db['rating'] as num).toDouble() : 0.0);
                    return rb.compareTo(ra); // 降順
                  case 'courts':
                    final ca = (da['courts'] is int ? da['courts'] as int : 0);
                    final cb = (db['courts'] is int ? db['courts'] as int : 0);
                    return cb.compareTo(ca); // 降順
                  default:
                    return (da['name'] ?? '').toString().compareTo((db['name'] ?? '').toString());
                }
              });
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
        onTap: () {
          if (widget.pickerMode) {
            Navigator.pop(context, {
              'id': docId, 'name': name, 'address': address,
              'phone': phone, 'parking': parking, 'toilets': toilets,
              'courts': courts,
            });
          } else {
            _showVenueDetail(data, docId);
          }
        },
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

  void _showVenueDetail(Map<String, dynamic> data, String docId) {
    final name = data['name'] ?? '';
    final address = data['address'] ?? '';
    final phone = (data['phone'] ?? '').toString();
    final parking = data['parking'] ?? 0;
    final toilets = data['toilets'] ?? 0;
    final courts = data['courts'] ?? 0;
    final hasAC = data['hasAC'] ?? false;
    final hasChangeRoom = data['hasChangeRoom'] ?? false;
    final hasShower = data['hasShower'] ?? false;
    final hasGallery = data['hasGallery'] ?? false;
    final station = (data['station'] ?? '').toString();
    final openTime = (data['openTime'] ?? '').toString();
    final closeTime = (data['closeTime'] ?? '').toString();
    final fee = (data['fee'] ?? '').toString();
    final eatArea = (data['eatArea'] ?? '').toString();
    final equipments = data['equipments'] is List ? List<Map<String, dynamic>>.from(data['equipments']) : <Map<String, dynamic>>[];
    final rating = (data['rating'] ?? 0).toDouble();
    final reviewCount = data['reviewCount'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 会場名
                  Row(children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    if (rating > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star, size: 18, color: Colors.amber),
                      Text(' ${rating.toStringAsFixed(1)} ($reviewCount)', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ]),
                  ]),
                  const SizedBox(height: 12),

                  // 住所
                  _detailRow(Icons.location_on, address),
                  if (phone.isNotEmpty) _detailRow(Icons.phone, phone),
                  if (station.isNotEmpty) _detailRow(Icons.train, station),
                  if (openTime.isNotEmpty || closeTime.isNotEmpty) _detailRow(Icons.access_time, '$openTime 〜 $closeTime'),
                  if (fee.isNotEmpty) _detailRow(Icons.payments_outlined, fee),
                  if (eatArea.isNotEmpty) _detailRow(Icons.restaurant, eatArea),

                  const SizedBox(height: 16),

                  // 施設情報
                  const Text('施設情報', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    if (courts > 0) _detailChip(Icons.grid_view, '$courtsコート'),
                    if (parking > 0) _detailChip(Icons.local_parking, '駐車場 $parking台'),
                    if (toilets > 0) _detailChip(Icons.wc, 'トイレ $toilets箇所'),
                    if (hasAC) _detailChip(Icons.ac_unit, '空調あり'),
                    if (hasChangeRoom) _detailChip(Icons.checkroom, '更衣室あり'),
                    if (hasShower) _detailChip(Icons.shower, 'シャワーあり'),
                    if (hasGallery) _detailChip(Icons.visibility, '観覧席あり'),
                  ]),

                  // 貸出備品
                  if (equipments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('貸出備品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...equipments.map((eq) {
                      final eqFee = eq['fee'] as int? ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${eq['name']} × ${eq['qty']}個', style: const TextStyle(fontSize: 14))),
                          Text(eqFee == 0 ? '無料' : '¥$eqFee', style: TextStyle(fontSize: 14, color: eqFee == 0 ? AppTheme.success : AppTheme.textPrimary)),
                        ]),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // 編集ボタン
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => VenueRegisterScreen(existingVenue: data, venueId: docId)));
                        if (result == true) setState(() {});
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('この会場の情報を編集する'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
      ]),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
      ]),
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
