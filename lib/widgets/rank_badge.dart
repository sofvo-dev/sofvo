import 'package:flutter/material.dart';

/// 大会結果カード用の順位バッジ（優勝・準優勝・3位）。
/// pointHistory の rank（1〜3、それ以外は null）を渡す。null なら何も表示しない。
/// 目立つように塗りつぶし＋白文字のデザイン。
class RankBadge extends StatelessWidget {
  final int? rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final r = rank;
    if (r == null || r < 1 || r > 3) return const SizedBox.shrink();

    final label = switch (r) { 1 => '優勝', 2 => '準優勝', _ => '3位' };
    final color = switch (r) {
      1 => const Color(0xFFD4A017), // ゴールド
      2 => const Color(0xFF7C8A9E), // シルバー
      _ => const Color(0xFFB87333), // ブロンズ
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }
}
