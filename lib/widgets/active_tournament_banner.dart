import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../utils/tournament_status.dart';
import '../screens/tournament/tournament_detail_screen.dart';

/// ホーム上部に表示する「進行中の大会」バナー。
///
/// 自分が **エントリー済み** または **運営（主催・編集者・管理者・公式）** する大会で、
/// ステータスが進行中（開催中・決勝中・順位決定中）のものがあるときだけカードを表示する。
///
/// タップ時の遷移先は状況で出し分ける：
///  - まだ自分が入力すべき未完了の試合がある → **対戦表タブ**（スコア入力の入口）
///  - すべて完了している → **概要タブ**
///
/// 該当がなければ何も表示しない（高さ0）。
class ActiveTournamentBanner extends StatefulWidget {
  const ActiveTournamentBanner({super.key});

  @override
  State<ActiveTournamentBanner> createState() => _ActiveTournamentBannerState();
}

class _ActiveTournamentBannerState extends State<ActiveTournamentBanner> {
  // 進行中とみなすステータス（正規化後）
  static const _inProgressStatuses = ['開催中', '決勝中', '順位決定中'];

  /// 起動（プロセス）ごとに一度だけ自動遷移する。
  /// 毎回開くと「戻る→またその画面」のループになりホームに戻れなくなるため。
  static bool _autoOpenAttempted = false;

  List<_ActiveTournament> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final firestore = FirebaseFirestore.instance;

      // 進行中の大会は常に少数なので、まずステータスで絞ってから判定する。
      final snap = await firestore
          .collection('tournaments')
          .where('status', whereIn: _inProgressStatuses)
          .get();

      final List<_ActiveTournament> result = [];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;

        // 体験用デモ大会はどの画面でも一般表示しない（「さがす」と同じ扱い）
        if (data['isDemo'] == true) continue;

        final status = normalizeTournamentStatus(data['status']);
        if (!_inProgressStatuses.contains(status)) continue;

        // 自分のチームID（参加者として）
        final myTeamIds = await _loadMyTeamIds(doc.reference, uid);
        final isParticipant = myTeamIds.isNotEmpty;
        // このバナーは「自分が実際に関わる進行中の大会」だけを出す。
        // 公式・管理者の包括権限（canManageTournament）はここでは使わない
        // （使うと進行中の全大会が表示され、ホームが埋め尽くされてしまう）。
        final editors = List<String>.from(data['editors'] ?? []);
        final isOrganizer =
            data['organizerId'] == uid || editors.contains(uid);

        if (!isParticipant && !isOrganizer) continue;

        final pending =
            await _hasPendingInput(doc.reference, isOrganizer, myTeamIds);

        result.add(_ActiveTournament(
          tournament: data,
          status: status,
          isOrganizer: isOrganizer,
          hasPendingInput: pending,
        ));
      }

      if (mounted) {
        setState(() {
          _items = result;
          _loaded = true;
        });
      }

      // 大会中はその大会の画面しか見ないことが多いので、
      // 進行中が1件だけなら起動時に自動でその画面を開く（セッション中1回だけ）。
      if (!_autoOpenAttempted && result.length == 1) {
        _autoOpenAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _open(result.first);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// 大会内で自分が属するチームIDを取得（memberUids → enteredBy の順）
  Future<Set<String>> _loadMyTeamIds(
      DocumentReference tRef, String uid) async {
    final ids = <String>{};
    try {
      final byMember = await tRef
          .collection('entries')
          .where('memberUids', arrayContains: uid)
          .get();
      for (final e in byMember.docs) {
        final data = e.data();
        final tid = (data['teamId'] as String?)?.trim();
        ids.add(tid != null && tid.isNotEmpty ? tid : e.id);
      }
      if (ids.isEmpty) {
        final byOwner = await tRef
            .collection('entries')
            .where('enteredBy', isEqualTo: uid)
            .get();
        for (final e in byOwner.docs) {
          final data = e.data();
          final tid = (data['teamId'] as String?)?.trim();
          ids.add(tid != null && tid.isNotEmpty ? tid : e.id);
        }
      }
    } catch (_) {}
    return ids;
  }

  /// 自分が入力すべき未完了の試合があるか。
  /// - 運営者: 未完了の試合が1つでもあれば true
  /// - 参加者: 未完了かつ自分のチームが関与（対戦/審判）する試合があれば true
  Future<bool> _hasPendingInput(
      DocumentReference tRef, bool isOrganizer, Set<String> myTeamIds) async {
    for (final group in const ['rounds', 'brackets']) {
      try {
        final groups = await tRef.collection(group).get();
        for (final g in groups.docs) {
          final matches = await g.reference.collection('matches').get();
          for (final m in matches.docs) {
            final d = m.data();
            final completed = (d['status'] ?? 'pending') == 'completed';
            if (completed) continue;
            if (isOrganizer) return true;
            final involved = myTeamIds.contains(d['teamAId']) ||
                myTeamIds.contains(d['teamBId']) ||
                myTeamIds.contains(d['refereeTeamId']) ||
                myTeamIds.contains(d['subRefereeTeamId']);
            if (involved) return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  void _open(_ActiveTournament item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // 入力が残っていれば対戦表（スコア入力の入口）、無ければ概要へ
        builder: (_) => TournamentDetailScreen(
          tournament: item.tournament,
          initialTab: item.hasPendingInput ? 'matches' : 'overview',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _items.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Column(
        children: [
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(item),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(_ActiveTournament item) {
    final t = item.tournament;
    final name = (t['name'] as String?)?.trim().isNotEmpty == true
        ? t['name'] as String
        : '大会';
    final pending = item.hasPendingInput;
    final ctaLabel = pending ? 'スコアを入力' : '結果を見る';
    final ctaIcon = pending ? Icons.edit_note : Icons.emoji_events;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.82),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_volleyball,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(ctaIcon,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 13),
                        const SizedBox(width: 3),
                        Text(
                          ctaLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTournament {
  final Map<String, dynamic> tournament;
  final String status;
  final bool isOrganizer;
  final bool hasPendingInput;

  _ActiveTournament({
    required this.tournament,
    required this.status,
    required this.isOrganizer,
    required this.hasPendingInput,
  });
}
