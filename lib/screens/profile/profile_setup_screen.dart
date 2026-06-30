import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../main.dart' show pendingReferrerUserId, pendingInviteCode;
import '../../services/notification_service.dart';
import '../../services/invite_service.dart';
import '../onboarding/onboarding_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _searchIdController = TextEditingController();
  final _bioController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String? _searchIdError;
  Timer? _debounceTimer;
  bool _isCheckingId = false;
  bool? _isIdAvailable;

  String _selectedPrefecture = '';
  String _selectedExperience = '1年未満';
  String _selectedGender = '';
  DateTime? _birthDate;
  bool _isLoading = false;

  static const List<String> _genderChoices = ['男性', '女性', 'その他'];

  final List<String> _prefectures = [
    '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
    '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
    '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
    '岐阜県', '静岡県', '愛知県', '三重県',
    '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
    '鳥取県', '島根県', '岡山県', '広島県', '山口県',
    '徳島県', '香川県', '愛媛県', '高知県',
    '福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
  ];

  final List<String> _experiences = [
    '1年未満',
    '1〜3年',
    '3〜5年',
    '5〜10年',
    '10年以上',
  ];

  @override
  void initState() {
    super.initState();
    // 招待リンク（?code=）経由なら招待コードを初期入力しておく。
    // 自動取得できない新規インストール経路でも、本人が手入力できる。
    if (pendingInviteCode != null && pendingInviteCode!.isNotEmpty) {
      _inviteCodeController.text = pendingInviteCode!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nicknameController.dispose();
    _searchIdController.dispose();
    _bioController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _checkSearchIdAvailability(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < 3 || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      setState(() {
        _isIdAvailable = null;
        _isCheckingId = false;
      });
      return;
    }

    setState(() => _isCheckingId = true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('searchId', isEqualTo: trimmed)
            .get();
        if (mounted) {
          setState(() {
            _isIdAvailable = existing.docs.isEmpty;
            _isCheckingId = false;
            _searchIdError = _isIdAvailable == false ? 'このユーザーIDは既に使用されています' : null;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isCheckingId = false);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPrefecture.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('活動エリアを選択してください'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('性別を選択してください'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('生年月日を選択してください'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ユーザーが見つかりません');

      // ユーザーID重複チェック
      final searchId = _searchIdController.text.trim();
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('searchId', isEqualTo: searchId)
          .get();
      if (existing.docs.isNotEmpty) {
        setState(() {
          _searchIdError = 'このユーザーIDは既に使用されています';
          _isLoading = false;
        });
        return;
      }

      // ※ profileCompleted: true をFirestoreに書くと、AuthGateのStreamBuilderが
      //   即座に反応してMainTabScreenに切り替わり、このWidgetがunmountされる。
      //   そのため、Navigator参照を事前に保存しておく。
      final navigator = Navigator.of(context);
      final nickname = _nicknameController.text.trim();
      final bio = _bioController.text.trim();

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await userRef.set({
        'uid': user.uid,
        'nickname': nickname,
        'bio': bio,
        'avatarUrl': '',
        'area': _selectedPrefecture,
        'experience': _selectedExperience,
        'searchId': searchId,
        'totalPoints': 0,
        'seasonPoints': 0,
        'title': 'ビギナー',
        'stats': {
          'tournamentsPlayed': 0,
          'tournamentsHosted': 0,
          'wins': 0,
          'losses': 0,
          'championships': 0,
          'helperCount': 0,
        },
        'settings': {
          'helperAvailable': false,
          'notificationEnabled': true,
          'calendarSync': false,
          'privacy': 'public',
        },
        'followersCount': 0,
        'followingCount': 0,
        'profileCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 個人情報はprivateサブコレクションに保存（本人のみ読み書き可能）
      await userRef.collection('private').doc('info').set({
        'email': user.email,
        'gender': _selectedGender,
        'birthDate': Timestamp.fromDate(_birthDate!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 友達紹介リンクからの登録 → 自動相互フォロー
      if (pendingReferrerUserId != null && pendingReferrerUserId != user.uid) {
        await _processReferral(user.uid, nickname);
      }

      // 招待コード入力 → 相互フォロー＋チーム参加（redeemInvite で確定）
      // ここで処理したら pendingInviteCode を消し、AuthGate 側の二重実行を防ぐ。
      final inviteCode = _inviteCodeController.text.trim();
      if (inviteCode.isNotEmpty) {
        pendingInviteCode = null;
        try {
          final result = await InviteService.redeemInvite(inviteCode);
          final teamName = (result['teamName'] ?? '') as String;
          final requestedTeam = result['requestedTeam'] == true;
          final joinedTeam = result['joinedTeam'] == true;
          if (mounted && teamName.isNotEmpty) {
            final msg = requestedTeam
                ? 'チーム「$teamName」に参加リクエストを送りました。承認をお待ちください'
                : joinedTeam
                    ? 'チーム「$teamName」に参加しました！'
                    : '';
            if (msg.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: AppTheme.success),
              );
            }
          }
        } catch (e) {
          debugPrint('招待コードの引き換えに失敗: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('招待コードが無効か、期限切れの可能性があります'), backgroundColor: AppTheme.warning),
            );
          }
        }
      }

      // pushAndRemoveUntilではなくpushを使用する。
      // pushAndRemoveUntilを使うとAuthGateがウィジェットツリーから消え、
      // ログアウトやアカウント削除時に認証状態の変化を検知できなくなる。
      // pushならAuthGateが残り、OnboardingScreen完了後にpopで戻れる。
      navigator.push(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(() {
              String errorMessage = '保存に失敗しました。';
              if (e.toString().contains('network') || e.toString().contains('unavailable')) {
                errorMessage = 'ネットワークに接続できません。接続を確認してもう一度お試しください。';
              } else if (e.toString().contains('permission')) {
                errorMessage = 'アクセス権限がありません。再ログインしてお試しください。';
              }
              return errorMessage;
            }()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 紹介リンク経由の自動相互フォロー
  Future<void> _processReferral(String myUid, String myNickname) async {
    final referrerUid = pendingReferrerUserId!;
    pendingReferrerUserId = null; // 一度だけ処理

    try {
      final firestore = FirebaseFirestore.instance;
      final myRef = firestore.collection('users').doc(myUid);
      final referrerRef = firestore.collection('users').doc(referrerUid);

      // 紹介者が存在するか確認
      final referrerDoc = await referrerRef.get();
      if (!referrerDoc.exists) return;
      final referrerData = referrerDoc.data() ?? {};
      final referrerName = (referrerData['nickname'] ?? '名前なし').toString();

      // 新規ユーザー → 紹介者 をフォロー
      await myRef.collection('following').doc(referrerUid).set({
        'nickname': referrerName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await referrerRef.collection('followers').doc(myUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 紹介者 → 新規ユーザー をフォロー
      // カウント更新はCloud Functionが自動処理
      await referrerRef.collection('following').doc(myUid).set({
        'nickname': myNickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await myRef.collection('followers').doc(referrerUid).set({
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 紹介者に通知を送る
      NotificationService.sendFollowNotification(
        targetUserId: referrerUid,
        senderId: myUid,
        senderName: myNickname,
        senderAvatar: '',
      );
    } catch (e) {
      debugPrint('紹介リンクの相互フォロー処理に失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // ── ステップ表示 ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '最終ステップ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1.0,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'はじめまして！\nプロフィールを設定しましょう',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'あとから変更できます',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // ── ニックネーム ──
                const Text(
                  'ニックネーム *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nicknameController,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '表示名を入力',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'ニックネームを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── ユーザーID ──
                const Text(
                  'ユーザーID *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'あなたを識別するIDです（英数字・アンダースコア、一度設定すると変更できません）',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _searchIdController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '例: volleyball_taro',
                    prefixIcon: const Icon(Icons.alternate_email),
                    errorText: _searchIdError,
                    suffixIcon: _isCheckingId
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            ),
                          )
                        : _isIdAvailable == true
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : _isIdAvailable == false
                                ? const Icon(Icons.cancel, color: Colors.red)
                                : null,
                  ),
                  onChanged: (value) {
                    if (_searchIdError != null) {
                      setState(() => _searchIdError = null);
                    }
                    _checkSearchIdAvailability(value);
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'ユーザーIDを入力してください';
                    }
                    if (v.trim().length < 3) {
                      return '3文字以上で入力してください';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                      return '英数字とアンダースコアのみ使用できます';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── 活動エリア ──
                const Text(
                  '活動エリア *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPrefecture.isEmpty
                      ? null
                      : _selectedPrefecture,
                  hint: const Text('都道府県を選択'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: _prefectures
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedPrefecture = v ?? ''),
                ),
                const SizedBox(height: 24),

                // ── 競技歴 ──
                const Text(
                  '競技歴',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _experiences.map((exp) {
                    final selected = _selectedExperience == exp;
                    return ChoiceChip(
                      label: Text(exp),
                      selected: selected,
                      onSelected: (s) {
                        if (s) {
                          setState(() => _selectedExperience = exp);
                        }
                      },
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── 性別 ──
                const Text(
                  '性別 *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genderChoices.map((g) {
                    final selected = _selectedGender == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      onSelected: (s) {
                        if (s) setState(() => _selectedGender = g);
                      },
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── 生年月日 ──
                const Text(
                  '生年月日 *',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime(2000, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: now,
                      locale: const Locale('ja'),
                    );
                    if (picked != null) {
                      setState(() => _birthDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18,
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
                        const Spacer(),
                        Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 自己紹介 ──
                const Text(
                  '自己紹介',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 120,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '一言自己紹介（任意）',
                  ),
                ),
                const SizedBox(height: 24),

                // ── 招待コード ──
                const Text(
                  '招待コード',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '友達やチームから招待された方は入力してください（任意）',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _inviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 16, letterSpacing: 2),
                  decoration: const InputDecoration(
                    hintText: '例: ABC234',
                    prefixIcon: Icon(Icons.card_giftcard, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 32),

                // ── 保存ボタン ──
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('プロフィールを保存'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
