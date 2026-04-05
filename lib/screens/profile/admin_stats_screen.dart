import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import 'admin_user_list_screen.dart';

/// ユーザー統計ダッシュボード（公式アカウント専用）
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late Future<List<int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  Future<List<int>> _loadCounts() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').count().get(),
      FirebaseFirestore.instance.collection('tournaments').count().get(),
      FirebaseFirestore.instance.collection('posts').count().get(),
      FirebaseFirestore.instance.collection('chats').count().get(),
      FirebaseFirestore.instance.collection('venues').count().get(),
      FirebaseFirestore.instance.collection('prizes').count().get(),
    ]);
    return results.map((r) => r.count ?? 0).toList();
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ユーザー統計', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<int>>(
        future: _countsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          final counts = snapshot.data!;
          final items = [
            _StatItem(icon: Icons.people_rounded, label: '総ユーザー数', count: counts[0], color: AppTheme.primaryColor, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserListScreen()));
            }),
            _StatItem(icon: Icons.emoji_events_rounded, label: '総大会数', count: counts[1], color: AppTheme.accentColor),
            _StatItem(icon: Icons.article_rounded, label: '総投稿数', count: counts[2], color: Colors.teal),
            _StatItem(icon: Icons.chat_rounded, label: '総チャット数', count: counts[3], color: Colors.indigo),
            _StatItem(icon: Icons.location_on_rounded, label: '総会場数', count: counts[4], color: Colors.deepOrange),
            _StatItem(icon: Icons.card_giftcard_rounded, label: '総景品数', count: counts[5], color: Colors.purple),
          ];

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              setState(() { _countsFuture = _loadCounts(); });
              await _countsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => items[index],
            ),
          );
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
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
              Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
