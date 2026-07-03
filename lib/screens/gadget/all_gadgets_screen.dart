import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../profile/my_page_screen.dart';

/// みんなのガジェット一覧（公式アカウント・管理者専用）
/// 全ユーザーが登録したガジェットを collectionGroup で横断表示する。
/// Firestore ルール側で isOfficial / isAdmin のみ読み取り可。
class AllGadgetsScreen extends StatefulWidget {
  const AllGadgetsScreen({super.key});

  @override
  State<AllGadgetsScreen> createState() => _AllGadgetsScreenState();
}

class _AllGadgetsScreenState extends State<AllGadgetsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filterCategory = 'すべて';

  @override
  void initState() {
    super.initState();
    _future = _loadAllGadgets();
  }

  Future<List<Map<String, dynamic>>> _loadAllGadgets() async {
    final firestore = FirebaseFirestore.instance;
    // orderBy なし（コレクショングループ用インデックス不要）。ソートはクライアント側で行う
    final snap = await firestore.collectionGroup('gadgets').get();

    final gadgets = <Map<String, dynamic>>[];
    final ownerUids = <String>{};
    for (final doc in snap.docs) {
      final ownerRef = doc.reference.parent.parent; // users/{uid}
      if (ownerRef == null) continue;
      final data = Map<String, dynamic>.from(doc.data());
      data['ownerUid'] = ownerRef.id;
      gadgets.add(data);
      ownerUids.add(ownerRef.id);
    }

    // 所有者のニックネームをまとめて取得
    final nicknames = <String, String>{};
    await Future.wait(ownerUids.map((uid) async {
      try {
        final userDoc = await firestore.collection('users').doc(uid).get();
        nicknames[uid] = (userDoc.data()?['nickname'] ?? '名前なし').toString();
      } catch (_) {
        nicknames[uid] = '名前なし';
      }
    }));
    for (final g in gadgets) {
      g['ownerNickname'] = nicknames[g['ownerUid']] ?? '名前なし';
    }

    // 新しい順にソート
    gadgets.sort((a, b) {
      final tA = a['createdAt'];
      final tB = b['createdAt'];
      final dA = tA is Timestamp ? tA.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      final dB = tB is Timestamp ? tB.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      return dB.compareTo(dA);
    });
    return gadgets;
  }

  List<String> _categories(List<Map<String, dynamic>> gadgets) {
    final set = <String>{};
    for (final g in gadgets) {
      final c = (g['category'] ?? '').toString();
      if (c.isNotEmpty) set.add(c);
    }
    return ['すべて', ...set];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('みんなのガジェット',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('ガジェットの取得に失敗しました\n（公式アカウント・管理者のみ利用できます）',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final all = snapshot.data!;
          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('まだガジェットが登録されていません',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          final categories = _categories(all);
          final gadgets = _filterCategory == 'すべて'
              ? all
              : all.where((g) => (g['category'] ?? '') == _filterCategory).toList();

          return Column(
            children: [
              // ── カテゴリフィルター ──
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final selected = c == _filterCategory;
                    return ChoiceChip(
                      label: Text(c, style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : AppTheme.textPrimary)),
                      selected: selected,
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _filterCategory = c),
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: gadgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildGadgetCard(gadgets[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGadgetCard(Map<String, dynamic> g) {
    final name = (g['name'] ?? '') as String;
    final category = (g['category'] ?? '') as String;
    final imageUrl = (g['imageUrl'] ?? '') as String;
    final memo = (g['memo'] ?? '') as String;
    final ownerUid = (g['ownerUid'] ?? '') as String;
    final ownerNickname = (g['ownerNickname'] ?? '名前なし') as String;
    final amazonUrl = (g['amazonAffiliateUrl'] ?? '') as String;
    final rakutenUrl = (g['rakutenAffiliateUrl'] ?? '') as String;
    final affiliateUrl = amazonUrl.isNotEmpty ? amazonUrl : rakutenUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 画像 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Container(color: Colors.grey[100]),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.devices_other_outlined,
                            color: Colors.grey, size: 24),
                      ),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.devices_other_outlined,
                          color: Colors.grey, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // ── 情報 ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : '（名称なし）',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(category,
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryColor)),
                      ),
                  ],
                ),
                if (memo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(memo,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    // 所有者 → プロフィールへ
                    Expanded(
                      child: GestureDetector(
                        onTap: ownerUid.isEmpty
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        MyPageScreen(targetUserId: ownerUid))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(ownerNickname,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryColor,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppTheme.primaryColor),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (affiliateUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(affiliateUrl),
                            mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new,
                                size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 2),
                            Text('商品を見る',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
