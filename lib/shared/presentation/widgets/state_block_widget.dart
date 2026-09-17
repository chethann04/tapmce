import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_motion.dart';

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
    final isReduced = AppMotion.isReducedMotion(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sp5,
        vertical: AppSpacing.sp8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          isReduced
              ? Container(
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
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: AppMotion.slow,
                  curve: AppMotion.emphasizedEasing,
                  builder: (context, val, child) {
                    return Transform.translate(
                      offset: Offset(0, (1.0 - val) * 8.0),
                      child: Opacity(
                        opacity: val,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
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

