import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_theme.dart';
import '../tournament/tournament_detail_screen.dart';

/// マイページ／プロフィール画面の「フォト」セクションに置く横スクロール行。
/// 自分（またはそのユーザー）がアップした大会フォトを大会ごとに表示し、
/// タップで [UserPhotosScreen] へ遷移する。
class PhotoCardsRow extends StatefulWidget {
  final String userId;
  final String displayName;
  const PhotoCardsRow({super.key, required this.userId, this.displayName = ''});

  @override
  State<PhotoCardsRow> createState() => _PhotoCardsRowState();
}

class _PhotoCardsRowState extends State<PhotoCardsRow> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPhotoGroups();
  }

  // 自分がアップした大会フォトを collectionGroup で取得し、大会ごとにまとめる
  Future<List<Map<String, dynamic>>> _loadPhotoGroups() async {
    final firestore = FirebaseFirestore.instance;
    final snap = await firestore
        .collectionGroup('photos')
        .where('uploadedBy', isEqualTo: widget.userId)
        .get();

    final groups = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final tournamentRef = doc.reference.parent.parent; // tournaments/{id}
      if (tournamentRef == null) continue;
      final tid = tournamentRef.id;
      final data = doc.data();
      final imageUrl = (data['imageUrl'] as String?) ?? '';
      final createdAt = data['createdAt'];
      final dt = createdAt is Timestamp ? createdAt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

      final g = groups[tid];
      if (g == null) {
        groups[tid] = {
          'tournamentId': tid,
          'tournamentName': '大会',
          'coverUrl': imageUrl,
          'count': 1,
          'latest': dt,
        };
      } else {
        g['count'] = (g['count'] as int) + 1;
        if (dt.isAfter(g['latest'] as DateTime)) {
          g['latest'] = dt;
          g['coverUrl'] = imageUrl; // 最新写真をカバーに
        }
      }
    }

    if (groups.isEmpty) return [];

    // 大会名を取得
    await Future.wait(groups.keys.map((tid) async {
      try {
        final tDoc = await firestore.collection('tournaments').doc(tid).get();
        final tData = tDoc.data();
        if (tData != null) {
          final name = (tData['title'] ?? tData['name'] ?? '大会') as String;
          groups[tid]!['tournamentName'] = name.isEmpty ? '大会' : name;
        }
      } catch (_) {}
    }));

    final result = groups.values.toList()
      ..sort((a, b) => (b['latest'] as DateTime).compareTo(a['latest'] as DateTime));
    if (result.length > 10) result.removeRange(10, result.length);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text('フォトの取得に失敗しました', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(height: 130, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)));
        }

        final groups = snapshot.data!;
        if (groups.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: Text('まだフォトがありません', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          );
        }

        return SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final g = groups[index];
              final coverUrl = (g['coverUrl'] as String?) ?? '';
              final name = (g['tournamentName'] as String?) ?? '大会';
              final count = (g['count'] as int?) ?? 0;

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => UserPhotosScreen(userId: widget.userId, displayName: widget.displayName))),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: coverUrl.isEmpty
                                ? Container(width: 120, height: 120, color: Colors.grey[100],
                                    child: const Icon(Icons.image, color: AppTheme.textHint))
                                : CachedNetworkImage(
                                    imageUrl: coverUrl,
                                    width: 120, height: 120, fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(width: 120, height: 120, color: Colors.grey[100]),
                                    errorWidget: (_, __, ___) => Container(width: 120, height: 120, color: Colors.grey[100],
                                        child: const Icon(Icons.broken_image, color: AppTheme.textHint)),
                                  ),
                          ),
                          // 枚数バッジ
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library, size: 11, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// ユーザーがアップロードした大会フォトを「大会ごと」にまとめて表示する画面。
/// マイページ「フォト」セクションの「すべて見る」から遷移する。
class UserPhotosScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  const UserPhotosScreen({super.key, required this.userId, this.displayName});

  @override
  State<UserPhotosScreen> createState() => _UserPhotosScreenState();
}

/// 大会ごとにまとめたフォト群
class _TournamentPhotoGroup {
  final String tournamentId;
  String tournamentName;
  final List<QueryDocumentSnapshot> photos;
  DateTime latest; // グループ内で最も新しい写真の作成日時（並び替え用）

  _TournamentPhotoGroup({
    required this.tournamentId,
    required this.tournamentName,
    required this.photos,
    required this.latest,
  });
}

class _UserPhotosScreenState extends State<UserPhotosScreen> {
  late Future<List<_TournamentPhotoGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPhotos();
  }

  Future<List<_TournamentPhotoGroup>> _loadPhotos() async {
    final firestore = FirebaseFirestore.instance;

    // collectionGroup で全大会の photos を横断し、自分がアップしたものだけ取得
    final snap = await firestore
        .collectionGroup('photos')
        .where('uploadedBy', isEqualTo: widget.userId)
        .get();

    // 大会IDごとにグルーピング
    final groups = <String, _TournamentPhotoGroup>{};
    for (final doc in snap.docs) {
      final tournamentRef = doc.reference.parent.parent; // tournaments/{id}
      if (tournamentRef == null) continue;
      final tid = tournamentRef.id;
      final data = doc.data();
      final createdAt = data['createdAt'];
      final dt = createdAt is Timestamp ? createdAt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

      final g = groups[tid];
      if (g == null) {
        groups[tid] = _TournamentPhotoGroup(
          tournamentId: tid,
          tournamentName: '大会',
          photos: [doc],
          latest: dt,
        );
      } else {
        g.photos.add(doc);
        if (dt.isAfter(g.latest)) g.latest = dt;
      }
    }

    if (groups.isEmpty) return [];

    // 各大会名を取得
    await Future.wait(groups.keys.map((tid) async {
      try {
        final tDoc = await firestore.collection('tournaments').doc(tid).get();
        final tData = tDoc.data();
        if (tData != null) {
          final name = (tData['title'] ?? tData['name'] ?? '大会') as String;
          groups[tid]!.tournamentName = name.isEmpty ? '大会' : name;
        }
      } catch (_) {
        // 取得失敗時はデフォルト名のまま
      }
    }));

    // 各グループ内の写真を新しい順に並べ替え
    for (final g in groups.values) {
      g.photos.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['createdAt'];
        final tb = (b.data() as Map<String, dynamic>)['createdAt'];
        final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    }

    // 大会自体は最新の写真がある順に並べる
    final result = groups.values.toList()
      ..sort((a, b) => b.latest.compareTo(a.latest));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('フォト'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<_TournamentPhotoGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('フォトの取得に失敗しました', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final groups = snapshot.data!;
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 56, color: AppTheme.textHint),
                  const SizedBox(height: 12),
                  const Text('まだフォトがありません', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('大会詳細の「フォト」から写真をアップロードできます', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) => _buildGroup(context, groups[index]),
          );
        },
      ),
    );
  }

  Widget _buildGroup(BuildContext context, _TournamentPhotoGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 大会見出し（タップで大会フォトタブへ）
        InkWell(
          onTap: () => _openTournamentPhotoTab(context, group),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(group.tournamentName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${group.photos.length}枚',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 写真グリッド（3列）
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: group.photos.length,
          itemBuilder: (context, i) {
            final data = group.photos[i].data() as Map<String, dynamic>;
            final imageUrl = (data['imageUrl'] as String?) ?? '';
            return GestureDetector(
              onTap: () => _showPhotoViewer(context, group, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[100]),
                  errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[100], child: const Icon(Icons.broken_image, color: AppTheme.textHint)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openTournamentPhotoTab(BuildContext context, _TournamentPhotoGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailScreen(
          tournament: {'id': group.tournamentId, 'name': group.tournamentName},
          initialTab: 'photo',
        ),
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, _TournamentPhotoGroup group, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => _PhotoViewerDialog(
        photos: group.photos,
        initialIndex: initialIndex,
        tournamentName: group.tournamentName,
      ),
    );
  }
}

/// フルスクリーンの写真ビューア（横スワイプ・ピンチズーム対応）
class _PhotoViewerDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot> photos;
  final int initialIndex;
  final String tournamentName;
  const _PhotoViewerDialog({
    required this.photos,
    required this.initialIndex,
    required this.tournamentName,
  });

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, i) {
              final data = widget.photos[i].data() as Map<String, dynamic>;
              final imageUrl = (data['imageUrl'] as String?) ?? '';
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              );
            },
          ),
          // 閉じるボタン
          Positioned(
            top: 40,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // 投稿者・日付・大会名
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Builder(builder: (context) {
                final data = widget.photos[_currentIndex].data() as Map<String, dynamic>;
                final uploaderName = (data['uploaderName'] as String?) ?? '';
                final createdAt = data['createdAt'];
                final dateStr = createdAt is Timestamp ? _formatDate(createdAt.toDate()) : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      [uploaderName, dateStr].where((s) => s.isNotEmpty).join(' ・ '),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.tournamentName,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
