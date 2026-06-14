import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../utils/tournament_status.dart';
import '../screens/tournament/tournament_detail_screen.dart';

/// ホーム上部に表示する「進行中の大会」バナー。
///
/// 自分がエントリー済み かつ ステータスが進行中（開催中・決勝中・順位決定中）の
/// 大会があるときだけカードを表示し、タップで大会詳細（対戦表＝スコア入力タブ）へ遷移する。
/// 該当がなければ何も表示しない（高さ0）。
class ActiveTournamentBanner extends StatefulWidget {
  const ActiveTournamentBanner({super.key});

  @override
  State<ActiveTournamentBanner> createState() => _ActiveTournamentBannerState();
}

class _ActiveTournamentBannerState extends State<ActiveTournamentBanner> {
  // 進行中とみなすステータス（正規化後）
  static const _inProgressStatuses = ['開催中', '決勝中', '順位決定中'];

  List<Map<String, dynamic>> _tournaments = [];
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
      // 進行中の大会は常に少数なので、まずステータスで絞ってから
      // 自分のエントリー有無を確認する（全大会スキャンを避ける）。
      final snap = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('status', whereIn: _inProgressStatuses)
          .get();

      final List<Map<String, dynamic>> result = [];
      for (final doc in snap.docs) {
        // 念のため正規化後のステータスでも確認
        final status = normalizeTournamentStatus(doc.data()['status']);
        if (!_inProgressStatuses.contains(status)) continue;

        // memberUids（メンバー）→ enteredBy（登録者）の順でエントリーを確認
        var entered = (await doc.reference
                .collection('entries')
                .where('memberUids', arrayContains: uid)
                .limit(1)
                .get())
            .docs
            .isNotEmpty;
        if (!entered) {
          entered = (await doc.reference
                  .collection('entries')
                  .where('enteredBy', isEqualTo: uid)
                  .limit(1)
                  .get())
              .docs
              .isNotEmpty;
        }
        if (entered) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          result.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _tournaments = result;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _open(Map<String, dynamic> tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // 対戦表タブ＝スコア入力への入口
        builder: (_) =>
            TournamentDetailScreen(tournament: tournament, initialTab: 'matches'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _tournaments.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Column(
        children: [
          for (final t in _tournaments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(t),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> t) {
    final name = (t['name'] as String?)?.trim().isNotEmpty == true
        ? t['name'] as String
        : '大会';
    final status = normalizeTournamentStatus(t['status']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(t),
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
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'スコアを入力',
                          style: TextStyle(
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
