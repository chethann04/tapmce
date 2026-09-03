import 'package:flutter/material.dart';
import 'package:placement_connect/core/theme/theme_extensions.dart';
import 'package:placement_connect/core/theme/app_spacing.dart';

class StateBlockWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const StateBlockWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    final iconBg = isError ? brandTheme.statusRejected.withValues(alpha: 0.12) : brandTheme.surfaceAlt;
    final iconColor = isError ? brandTheme.statusRejected : brandTheme.textMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sp5,
        vertical: AppSpacing.sp8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 26,
              color: iconColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sp3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sp2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: brandTheme.textMuted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sp4),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sp4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: brandTheme.brassSoft,
                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: brandTheme.brassPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
