import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';

/// 記事詳細画面
class ArticleDetailScreen extends StatelessWidget {
  final String articleId;
  final Map<String, dynamic> data;

  const ArticleDetailScreen({
    super.key,
    required this.articleId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().year}年${createdAt.toDate().month}月${createdAt.toDate().day}日'
        : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (thumbnailUrl.isNotEmpty)
              Image.network(
                thumbnailUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge + date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Author
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.verified,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('公式',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Divider(color: Colors.grey[200], height: 1),
                  const SizedBox(height: 20),

                  // Body
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
