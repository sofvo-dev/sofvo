import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class EmptyStateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });
}

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<EmptyStateAction> actions;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // TEST: 500px固定で変化があるか確認
    const topPadding = 500.0;

    return Padding(
      padding: const EdgeInsets.only(top: topPadding),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              for (final action in actions) ...[
                SizedBox(height: action.isPrimary ? 24 : 12),
                SizedBox(
                  width: double.infinity,
                  child: action.isPrimary
                      ? ElevatedButton.icon(
                          onPressed: action.onPressed,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: action.onPressed,
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      );
  }
}
