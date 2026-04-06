import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../widgets/certified_badge.dart';

/// 大会認定管理画面（公式アカウント用）
class CertificationScreen extends StatefulWidget {
  const CertificationScreen({super.key});

  @override
  State<CertificationScreen> createState() => _CertificationScreenState();
}

class _CertificationScreenState extends State<CertificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text('大会認定管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: '認定済み'),
            Tab(text: '未認定'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTournamentList(certified: true),
          _buildTournamentList(certified: false),
        ],
      ),
    );
  }

  Widget _buildTournamentList({required bool certified}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('大会がありません',
                  style: TextStyle(color: AppTheme.textSecondary)));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isCertified = data['isCertified'] == true;
          return certified ? isCertified : !isCertified;
        }).toList();

        if (docs.isEmpty) {
          return Center(
              child: Text(certified ? '認定済みの大会はありません' : '未認定の大会はありません',
                  style: const TextStyle(color: AppTheme.textSecondary)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildTournamentTile(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTournamentTile(String docId, Map<String, dynamic> data) {
    final title = data['title'] ?? '';
    final date = data['date'] ?? '';
    final organizerName = data['organizerName'] ?? '不明';
    final isCertified = data['isCertified'] == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCertificationDialog(docId, title, isCertified),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isCertified) const CertifiedBadge(size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$date  |  主催: $organizerName',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(
                isCertified ? Icons.verified : Icons.verified_outlined,
                color: isCertified ? Colors.amber : AppTheme.textHint,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCertificationDialog(
      String docId, String title, bool currentStatus) {
    final action = currentStatus ? '認定を解除' : '認定';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$action確認',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('「$title」を${action}しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  currentStatus ? AppTheme.error : Colors.amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(docId)
                  .update({'isCertified': !currentStatus});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '「$title」を${currentStatus ? '認定解除' : '認定'}しました'),
                  backgroundColor:
                      currentStatus ? AppTheme.textSecondary : Colors.amber[700],
                ));
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
