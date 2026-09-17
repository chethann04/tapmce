import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';

/// Frosted-glass floating top app bar with GPU-accelerated backdrop blur.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final double blurAmount;
  final double height;

  const GlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.blurAmount = 16.0,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final glassColor = isDark
        ? const Color(0xFF14161C).withValues(alpha: 0.75)
        : (theme.colorScheme.surface).withValues(alpha: 0.78);

    final borderColor = isDark
        ? const Color(0xFF2A2D36).withValues(alpha: 0.6)
        : (brandTheme?.cardBorder ?? Colors.black.withValues(alpha: 0.06));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.0),
            ),
          ),
          child: NavigationToolbar(
            leading: leading,
            middle: title,
            trailing: actions != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  )
                : null,
            centerMiddle: true,
          ),
        ),
      ),
    );
  }
}
