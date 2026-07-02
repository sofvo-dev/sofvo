import 'package:flutter/material.dart';

/// 大会結果カード用の順位バッジ（優勝・準優勝・3位）。
/// pointHistory の rank（1〜3、それ以外は null）を渡す。null なら何も表示しない。
class RankBadge extends StatelessWidget {
  final int? rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final r = rank;
    if (r == null || r < 1 || r > 3) return const SizedBox.shrink();

    final label = switch (r) { 1 => '優勝', 2 => '準優勝', _ => '3位' };
    final color = switch (r) {
      1 => const Color(0xFFB8860B), // ゴールド
      2 => const Color(0xFF708090), // シルバー
      _ => const Color(0xFFCD7F32), // ブロンズ
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 10, color: color),
          const SizedBox(width: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
