import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_haptics.dart';

/// Brand brass-styled pull-to-refresh indicator wrapper.
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = brandTheme?.brassPrimary ?? const Color(0xFFC89446);
    final bgColor = isDark ? const Color(0xFF1E2026) : Colors.white;

    return RefreshIndicator(
      onRefresh: () async {
        AppHaptics.mediumImpact();
        await onRefresh();
      },
      color: primaryColor,
      backgroundColor: bgColor,
      strokeWidth: 2.5,
      displacement: 40.0,
      child: child,
    );
  }
}
