import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../config/app_theme.dart';

class EmptyStateView extends StatefulWidget {
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
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

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

class _EmptyStateViewState extends State<EmptyStateView> {
  double _topPadding = 120;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final containerY = box.localToGlobal(Offset.zero).dy;
    final screenH = MediaQuery.of(context).size.height;
    final targetY = screenH * 0.35;
    final padding = (targetY - containerY).clamp(20.0, box.size.height * 0.5);

    if (!_measured || (padding - _topPadding).abs() > 2) {
      setState(() {
        _topPadding = padding;
        _measured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: EdgeInsets.only(top: _topPadding),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Icon(widget.icon, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                for (final action in widget.actions) ...[
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
        ),
      ],
    );
  }
}
