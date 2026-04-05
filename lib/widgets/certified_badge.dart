import 'package:flutter/material.dart';

/// 公式認定大会バッジ
class CertifiedBadge extends StatelessWidget {
  final double size;

  const CertifiedBadge({
    super.key,
    this.size = 16,
  });

  /// isCertified フラグが true の場合のみバッジを返す
  static Widget? maybeShow(bool isCertified, {double size = 16}) {
    if (!isCertified) return null;
    return CertifiedBadge(size: size);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '公式認定大会',
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.verified,
          size: size,
          color: Colors.amber,
        ),
      ),
    );
  }
}
