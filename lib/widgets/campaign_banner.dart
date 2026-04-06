import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

/// アプリ内にキャンペーンバナー/ポップアップを表示するウィジェット
///
/// [targetScreen] にマッチするアクティブなキャンペーンを表示する。
/// banner タイプはバナー画像、popup タイプはダイアログで表示。
class CampaignBanner extends StatelessWidget {
  final String targetScreen;

  const CampaignBanner({super.key, required this.targetScreen});

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.fromDate(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('campaigns')
          .where('active', isEqualTo: true)
          .where('targetScreen', isEqualTo: targetScreen)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        // Filter by date range client-side
        final nowDt = DateTime.now();
        final activeCampaigns = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          if (startDate != null && nowDt.isBefore(startDate)) return false;
          if (endDate != null && nowDt.isAfter(endDate)) return false;
          return true;
        }).toList();

        if (activeCampaigns.isEmpty) return const SizedBox.shrink();

        // Show popup campaigns via dialog, banners inline
        final bannerCampaigns = <QueryDocumentSnapshot>[];
        for (final doc in activeCampaigns) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'banner';
          if (type == 'popup') {
            // Schedule popup to show after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showPopupDialog(context, data);
            });
          } else {
            bannerCampaigns.add(doc);
          }
        }

        if (bannerCampaigns.isEmpty) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: bannerCampaigns.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _CampaignBannerItem(data: data);
          }).toList(),
        );
      },
    );
  }

  static void _showPopupDialog(
      BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final linkUrl = data['linkUrl'] as String? ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description,
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          if (linkUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(linkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor),
              child: const Text('詳しく見る'),
            ),
        ],
      ),
    );
  }
}

class _CampaignBannerItem extends StatefulWidget {
  final Map<String, dynamic> data;

  const _CampaignBannerItem({required this.data});

  @override
  State<_CampaignBannerItem> createState() => _CampaignBannerItemState();
}

class _CampaignBannerItemState extends State<_CampaignBannerItem> {
  bool _dismissed = false;

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final imageUrl = widget.data['imageUrl'] as String? ?? '';
    final linkUrl = widget.data['linkUrl'] as String? ?? '';
    final title = widget.data['title'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        children: [
          GestureDetector(
            onTap: linkUrl.isNotEmpty ? () => _openLink(linkUrl) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor)),
                        ),
                      ),
                    )
                  : Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor)),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
