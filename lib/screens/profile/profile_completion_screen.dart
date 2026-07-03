import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../utils/search_normalize.dart';

/// 必須化以前に登録した既存ユーザー向けの「プロフィール追加入力」画面。
///
/// ユーザーID・性別・生年月日・都道府県のうち未入力の項目だけを聞く。
/// MainTabScreen 起動時のチェック（_checkProfileCompletion）から
/// 全項目が埋まるまで毎回表示される（スキップ不可・公式/デモは対象外）。
class ProfileCompletionScreen extends StatefulWidget {
  final bool needsSearchId;
  final bool needsGender;
  final bool needsBirthDate;
  final bool needsArea;

  const ProfileCompletionScreen({
    super.key,
    required this.needsSearchId,
    required this.needsGender,
    required this.needsBirthDate,
    required this.needsArea,
  });

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _searchIdController = TextEditingController();
  String _selectedGender = '';
  DateTime? _birthDate;
  String _selectedPrefecture = '';
  bool _isSaving = false;

  static const List<String> _genderChoices = ['男性', '女性', 'その他'];
  static const List<String> _prefectures = [
    '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
    '岐阜県', '静岡県', '愛知県', '三重県',
    '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
    '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県',
    '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
  ];

  @override
  void dispose() {
    _searchIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // ── 入力チェック（必要な項目のみ） ──
    final searchId = _searchIdController.text.trim();
    if (widget.needsSearchId) {
      if (searchId.isEmpty) {
        _warn('ユーザーIDを入力してください');
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(searchId)) {
        _warn('ユーザーIDは半角英数字とアンダースコア（_）のみ使えます');
        return;
      }
    }
    if (widget.needsGender && _selectedGender.isEmpty) {
      _warn('性別を選択してください');
      return;
    }
    if (widget.needsBirthDate && _birthDate == null) {
      _warn('生年月日を選択してください');
      return;
    }
    if (widget.needsArea && _selectedPrefecture.isEmpty) {
      _warn('都道府県を選択してください');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // ユーザーIDの重複チェック
      if (widget.needsSearchId) {
        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('searchId', isEqualTo: searchId)
            .get();
        if (existing.docs.any((d) => d.id != uid)) {
          _warn('このユーザーIDは既に使用されています');
          setState(() => _isSaving = false);
          return;
        }
      }

      final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (widget.needsSearchId) {
        update['searchId'] = searchId;
        update['searchIdNorm'] = normalizeForSearch(searchId);
      }
      if (widget.needsArea) {
        update['area'] = _selectedPrefecture;
      }
      await userRef.update(update);

      if (widget.needsGender || widget.needsBirthDate) {
        final privateData = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
        if (widget.needsGender) privateData['gender'] = _selectedGender;
        if (widget.needsBirthDate) privateData['birthDate'] = Timestamp.fromDate(_birthDate!);
        await userRef.collection('private').doc('info').set(privateData, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールを更新しました。ご協力ありがとうございます！'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      debugPrint('プロフィール追加入力の保存に失敗: $e');
      if (mounted) {
        _warn('保存に失敗しました。通信環境を確認してもう一度お試しください');
        setState(() => _isSaving = false);
      }
    }
  }

  void _warn(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.warning),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));

  @override
  Widget build(BuildContext context) {
    // 全項目が埋まるまで閉じられない（戻る操作を無効化）
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('プロフィールの追加入力', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'いつもSofvoをご利用ありがとうございます。\n年齢別・女性限定などの大会機能や、お住まいの地域に合わせた大会表示のため、以下のプロフィール入力をお願いしています。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ),
                const SizedBox(height: 24),

                // ── ユーザーID ──
                if (widget.needsSearchId) ...[
                  _label('ユーザーID *'),
                  const SizedBox(height: 4),
                  const Text('半角英数字とアンダースコア（_）。友達検索やQRコードで使われます。あとから変更できません。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchIdController,
                    decoration: const InputDecoration(
                      hintText: '例: volleyball_taro',
                      prefixIcon: Icon(Icons.alternate_email, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── 性別 ──
                if (widget.needsGender) ...[
                  _label('性別 *'),
                  const SizedBox(height: 8),
                  Row(
                    children: _genderChoices.map((g) {
                      final selected = _selectedGender == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: selected,
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _selectedGender = g),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── 生年月日 ──
                if (widget.needsBirthDate) ...[
                  _label('生年月日 *'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _birthDate ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        locale: const Locale('ja'),
                      );
                      if (picked != null) setState(() => _birthDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined,
                              color: _birthDate != null ? AppTheme.primaryColor : AppTheme.textHint),
                          const SizedBox(width: 12),
                          Text(
                            _birthDate != null
                                ? '${_birthDate!.year}年${_birthDate!.month}月${_birthDate!.day}日'
                                : '生年月日を選択',
                            style: TextStyle(
                              fontSize: 15,
                              color: _birthDate != null ? AppTheme.textPrimary : AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── 都道府県 ──
                if (widget.needsArea) ...[
                  _label('活動エリア（都道府県） *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPrefecture.isEmpty ? null : _selectedPrefecture,
                    hint: const Text('都道府県を選択'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: _prefectures
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPrefecture = v ?? ''),
                  ),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
