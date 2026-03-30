import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 公式アカウントバッジ（認証マーク）
class OfficialBadge extends StatelessWidget {
  final double size;
  final Color? color;

  const OfficialBadge({
    super.key,
    this.size = 16,
    this.color,
  });

  /// isOfficial フラグが true の場合のみバッジを返す
  static Widget? maybeShow(Map<String, dynamic>? userData, {double size = 16, Color? color}) {
    if (userData == null) return null;
    if (userData['isOfficial'] != true) return null;
    return OfficialBadge(size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(
        Icons.verified,
        size: size,
        color: color ?? AppTheme.accentColor,
      ),
    );
  }
}
