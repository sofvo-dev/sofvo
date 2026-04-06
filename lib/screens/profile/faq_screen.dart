import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// FAQ画面（ユーザー用）
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _searchQuery = '';

  static const _categories = ['一般', 'アカウント', '大会', 'チャット', 'ポイント'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('よくある質問',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── 検索バー ──
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              cursorColor: AppTheme.accentColor,
              decoration: InputDecoration(
                hintText: '質問を検索...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white60, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.accentColor, width: 1),
                ),
              ),
            ),
          ),

          // ── FAQ リスト ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('faq')
                  .where('active', isEqualTo: true)
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_outlined,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('FAQはまだありません',
                            style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }

                // Filter by search query
                final filteredDocs = _searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final q =
                            (data['question'] as String? ?? '').toLowerCase();
                        final a =
                            (data['answer'] as String? ?? '').toLowerCase();
                        return q.contains(_searchQuery) ||
                            a.contains(_searchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('該当するFAQが見つかりません',
                            style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }

                // Group by category
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final doc in filteredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final cat = data['category'] as String? ?? '一般';
                  grouped.putIfAbsent(cat, () => []);
                  grouped[cat]!.add(data);
                }

                // Sort categories by predefined order
                final sortedCategories = _categories
                    .where((c) => grouped.containsKey(c))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final category = sortedCategories[index];
                    final items = grouped[category]!;
                    return _CategorySection(
                        category: category, items: items);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;

  const _CategorySection({required this.category, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(category,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
        ...items.map((item) => _FaqTile(data: item)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _FaqTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final question = data['question'] as String? ?? '';
    final answer = data['answer'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            leading: Icon(Icons.help_outline,
                color: AppTheme.primaryColor, size: 22),
            title: Text(question,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            iconColor: AppTheme.primaryColor,
            collapsedIconColor: AppTheme.textHint,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(answer,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
