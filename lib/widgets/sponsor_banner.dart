import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

/// スポンサーバナーウィジェット
///
/// [placement] に一致する（または "all" の）アクティブなスポンサーを表示。
/// 日付範囲フィルタ、優先度ソート、インプレッション/クリック計測に対応。
class SponsorBanner extends StatefulWidget {
  /// 表示位置: "home_top", "home_bottom", "tournament_list", "chat_list"
  final String placement;

  const SponsorBanner({super.key, this.placement = 'home_top'});

  @override
  State<SponsorBanner> createState() => _SponsorBannerState();
}

class _SponsorBannerState extends State<SponsorBanner> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  int _totalPages = 0;

  /// Track which sponsor IDs have already been counted for impressions
  /// in this widget session to avoid duplicate counting.
  final Set<String> _impressionTracked = {};

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (_totalPages <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _totalPages;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _openLink(String url, String docId) async {
    // Track click
    FirebaseFirestore.instance
        .collection('sponsors')
        .doc(docId)
        .update({'clickCount': FieldValue.increment(1)});

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _trackImpression(String docId) {
    if (_impressionTracked.contains(docId)) return;
    _impressionTracked.add(docId);
    FirebaseFirestore.instance
        .collection('sponsors')
        .doc(docId)
        .update({'impressionCount': FieldValue.increment(1)});
  }

  /// Filter and sort sponsors by placement, date range, and priority
  List<QueryDocumentSnapshot> _filterAndSort(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Filter by placement
      final placement = data['placement'] as String? ?? 'home_top';
      if (placement != 'all' && placement != widget.placement) return false;
      // Filter by date range
      final startDate = (data['startDate'] as Timestamp?)?.toDate();
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      if (startDate != null && now.isBefore(startDate)) return false;
      if (endDate != null && now.isAfter(endDate)) return false;
      return true;
    }).toList();

    // Sort by priority descending, then shuffle within same priority
    filtered.sort((a, b) {
      final pa = ((a.data() as Map<String, dynamic>)['priority'] as num?)?.toInt() ?? 0;
      final pb = ((b.data() as Map<String, dynamic>)['priority'] as num?)?.toInt() ?? 0;
      if (pa != pb) return pb.compareTo(pa);
      // Random tiebreak for same priority
      return Random().nextInt(3) - 1;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsors')
          .where('active', isEqualTo: true)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final docs = _filterAndSort(allDocs);
        if (docs.isEmpty) return const SizedBox.shrink();

        // Track impressions for visible sponsors
        for (final doc in docs) {
          _trackImpression(doc.id);
        }

        // Update total pages and restart auto-scroll when data changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_totalPages != docs.length) {
            _totalPages = docs.length;
            _startAutoScroll();
          }
        });
        _totalPages = docs.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: docs.length,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final imageUrl = data['imageUrl'] as String? ?? '';
                    final linkUrl = data['linkUrl'] as String? ?? '';

                    return GestureDetector(
                      onTap: linkUrl.isNotEmpty
                          ? () => _openLink(linkUrl, doc.id)
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[100],
                            child: Center(
                              child: Icon(Icons.broken_image,
                                  color: AppTheme.textHint, size: 28),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (docs.length > 1) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(docs.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
