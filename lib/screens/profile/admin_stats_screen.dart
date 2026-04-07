import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'admin_user_list_screen.dart';
import '../tournament/tournament_management_screen.dart';
import '../tournament/venue_search_screen.dart';
import '../tournament/prize_search_screen.dart';

/// ユーザー統計ダッシュボード（公式アカウント専用）
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final _stats = <_StatData>[
    _StatData(icon: Icons.people_rounded, label: '総ユーザー数', collection: 'users', color: AppTheme.primaryColor),
    _StatData(icon: Icons.emoji_events_rounded, label: '総大会数', collection: 'tournaments', color: AppTheme.accentColor),
    _StatData(icon: Icons.article_rounded, label: '総投稿数', collection: 'posts', color: Colors.teal),
    _StatData(icon: Icons.location_on_rounded, label: '総会場数', collection: 'venues', color: Colors.deepOrange),
    _StatData(icon: Icons.card_giftcard_rounded, label: '総景品数', collection: 'prizes', color: Colors.purple),
  ];

  void _navigateTo(BuildContext context, int index) {
    final routes = <int, Widget>{
      0: const AdminUserListScreen(),
      1: const TournamentManagementScreen(),
      3: const VenueSearchScreen(),
      4: const PrizeSearchScreen(),
    };
    final screen = routes[index];
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait(_stats.map((s) => _loadCount(s)));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCount(_StatData stat) async {
    try {
      final snap = await FirebaseFirestore.instance.collection(stat.collection).count().get();
      stat.count = snap.count ?? 0;
      stat.error = false;
    } catch (_) {
      stat.count = 0;
      stat.error = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ユーザー統計', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadAll,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _stats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = _stats[index];
                  final hasTap = [0, 1, 3, 4].contains(index); // users, tournaments, venues, prizes
                  return _StatItem(
                    icon: s.icon,
                    label: s.label,
                    count: s.count,
                    color: s.color,
                    error: s.error,
                    onTap: hasTap ? () => _navigateTo(context, index) : null,
                  );
                },
              ),
            ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String collection;
  final Color color;
  int count = 0;
  bool error = false;

  _StatData({
    required this.icon,
    required this.label,
    required this.collection,
    required this.color,
  });
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool error;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.error = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
              error
                  ? Text('-', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textHint))
                  : Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
