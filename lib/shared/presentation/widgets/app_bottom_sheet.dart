import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_extensions.dart';

/// Helper to launch tactile, spring-animated bottom sheets with drag handle indicators.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool enableDrag = true,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = backgroundColor ??
        (isDark ? const Color(0xFF181A20) : theme.colorScheme.surface);

    final handleColor = isDark
        ? const Color(0xFF3A3D4A)
        : (brandTheme?.cardBorder ?? Colors.grey.shade300);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 32.0,
                spreadRadius: 0.0,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10.0),
              // Drag Handle Indicator
              Center(
                child: Container(
                  width: 38.0,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sp3),
              Flexible(child: builder(ctx)),
            ],
          ),
        );
      },
    );
  }
}
