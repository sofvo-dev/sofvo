import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// エントリー画面用のメンバー選択リスト（フォロー中から選ぶ）。
/// - 名前検索ボックス付き（フォロー中が多くても探せる）
/// - 過去に一緒にエントリーした回数が多い人を自動で上位表示（設定不要）
class FollowerMemberPicker extends StatefulWidget {
  final String uid;
  final Map<String, String> selectedMembers;
  final void Function(String uid, String name) onToggle;

  const FollowerMemberPicker({
    super.key,
    required this.uid,
    required this.selectedMembers,
    required this.onToggle,
  });

  /// uid → 一緒にエントリーした回数。ダイアログを開き直しても再計算しないようキャッシュ
  static final Map<String, Map<String, int>> _teammateCountsCache = {};

  /// 過去の大会（pointHistory）から「一緒にエントリーした回数」を集計する
  static Future<Map<String, int>> loadTeammateCounts(String uid) async {
    final cached = _teammateCountsCache[uid];
    if (cached != null) return cached;

    final counts = <String, int>{};
    try {
      final firestore = FirebaseFirestore.instance;
      final ph = await firestore
          .collection('users')
          .doc(uid)
          .collection('pointHistory')
          .get();
      // 直近20大会まで（読み取り量の上限）
      final tournamentIds = ph.docs.map((d) => d.id).take(20).toList();
      for (final tid in tournamentIds) {
        final entries = await firestore
            .collection('tournaments')
            .doc(tid)
            .collection('entries')
            .get();
        for (final e in entries.docs) {
          final data = e.data();
          final uids = <String>{
            ...List<String>.from((data['memberUids'] as List?) ?? []),
          };
          final leaderUid = (data['leaderUid'] ?? '').toString();
          final enteredBy = (data['enteredBy'] ?? '').toString();
          if (leaderUid.isNotEmpty) uids.add(leaderUid);
          if (enteredBy.isNotEmpty) uids.add(enteredBy);
          if (!uids.contains(uid)) continue; // 自分のチームのみ
          for (final m in uids) {
            if (m == uid) continue;
            counts[m] = (counts[m] ?? 0) + 1;
          }
        }
      }
    } catch (_) {
      // 集計に失敗しても一覧表示自体は続行する
    }
    _teammateCountsCache[uid] = counts;
    return counts;
  }

  @override
  State<FollowerMemberPicker> createState() => _FollowerMemberPickerState();
}

class _FollowerMemberPickerState extends State<FollowerMemberPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 名前検索 ──
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: '名前で検索',
            hintStyle: const TextStyle(fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.backgroundColor,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('users')
              .doc(widget.uid)
              .collection('following')
              .snapshots(),
          builder: (context, followSnap) {
            if (!followSnap.hasData) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            final followings = followSnap.data!.docs;
            if (followings.isEmpty) {
              return _emptyBox('フォロー中のユーザーがいません');
            }
            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                Future.wait(followings
                    .map((f) => firestore.collection('users').doc(f.id).get())),
                FollowerMemberPicker.loadTeammateCounts(widget.uid),
              ]),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor)));
                }
                final userDocs = snap.data![0] as List<DocumentSnapshot>;
                final counts = snap.data![1] as Map<String, int>;

                // 表示リストを構築（検索フィルタ → よく組む人順）
                final items = <_PickerItem>[];
                for (int i = 0; i < followings.length; i++) {
                  final doc = userDocs[i];
                  if (!doc.exists) continue;
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final name = (data['nickname'] ?? '名前なし').toString();
                  if (_query.isNotEmpty &&
                      !name.toLowerCase().contains(_query)) {
                    continue;
                  }
                  items.add(_PickerItem(
                    uid: followings[i].id,
                    name: name,
                    avatarUrl: (data['avatarUrl'] ?? '').toString(),
                    teammateCount: counts[followings[i].id] ?? 0,
                  ));
                }
                items.sort((a, b) {
                  final c = b.teammateCount.compareTo(a.teammateCount);
                  return c != 0 ? c : a.name.compareTo(b.name);
                });

                if (items.isEmpty) {
                  return _emptyBox(_query.isNotEmpty
                      ? '「${_searchController.text}」に一致する人がいません'
                      : 'フォロー中のユーザーがいません');
                }

                return Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected =
                          widget.selectedMembers.containsKey(item.uid);
                      return ListTile(
                        dense: item.teammateCount == 0,
                        leading: item.avatarUrl.isNotEmpty
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(item.avatarUrl),
                                radius: 18)
                            : CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                    item.name.isNotEmpty ? item.name[0] : '?',
                                    style: const TextStyle(
                                        color: AppTheme.primaryColor))),
                        title: Text(item.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: item.teammateCount > 0
                            ? Text('一緒にエントリー ${item.teammateCount}回',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.accentColor))
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.primaryColor)
                            : Icon(Icons.circle_outlined,
                                color: Colors.grey[400]),
                        onTap: () => widget.onToggle(item.uid, item.name),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12)),
      child: Center(
          child:
              Text(message, style: const TextStyle(color: AppTheme.textHint))),
    );
  }
}

class _PickerItem {
  final String uid;
  final String name;
  final String avatarUrl;
  final int teammateCount;
  _PickerItem({
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.teammateCount,
  });
}
