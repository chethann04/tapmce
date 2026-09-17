import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_haptics.dart';

class NavDestinationItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool hasBadge;
  final int? badgeCount;

  const NavDestinationItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.hasBadge = false,
    this.badgeCount,
  });
}

class FloatingPillNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavDestinationItem> items;

  const FloatingPillNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Hide nav bar when software keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive width calculation:
    // Small screens: width = screenWidth - 32px (16px margins)
    // Medium/Large screens: min(screenWidth - 48px, 440px max)
    final navWidth = math.min(screenWidth - 32.0, 440.0);

    // Surface & palette matching reference design
    final navBg = isDark
        ? const Color(0xFF181A20)
        : (theme.colorScheme.surface == Colors.white
            ? Colors.white
            : theme.colorScheme.surface);

    final navBorder = isDark
        ? const Color(0xFF2B2D36)
        : (brandTheme?.cardBorder ?? Colors.black.withValues(alpha: 0.06));

    final inactiveIconColor = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF71717A);

    final activeIconColor = isDark
        ? Colors.white
        : (brandTheme?.brassPrimary ?? const Color(0xFF0F172A));

    final activeBgColor = isDark
        ? const Color(0xFF2A2D37)
        : (brandTheme?.brassSoft ?? const Color(0xFFF1F5F9));

    return Positioned(
      left: 0,
      right: 0,
      bottom: (bottomInset > 0 ? bottomInset : 14.0) + 8.0,
      child: Center(
        child: SizedBox(
          width: navWidth,
          height: 68.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(100.0),
              border: Border.all(color: navBorder, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 28.0,
                  spreadRadius: 0.0,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                  blurRadius: 8.0,
                  spreadRadius: 0.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final itemWidth = items.isNotEmpty ? totalWidth / items.length : totalWidth;
                final itemAlignmentX = items.length > 1
                    ? -1.0 + (2.0 * selectedIndex / (items.length - 1))
                    : 0.0;

                return Stack(
                  children: [
                    // Smooth Gliding Active Pill Backdrop
                    AnimatedAlign(
                      alignment: Alignment(itemAlignmentX, 0.0),
                      duration: const Duration(milliseconds: 240),
                      curve: const Cubic(0.05, 0.7, 0.1, 1.0),
                      child: SizedBox(
                        width: itemWidth,
                        height: 52.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            color: activeBgColor,
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                        ),
                      ),
                    ),

                    // Navigation Items Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(items.length, (index) {
                        final isSelected = index == selectedIndex;
                        final item = items[index];
                        final iconData = (isSelected && item.selectedIcon != null)
                            ? item.selectedIcon!
                            : item.icon;

                        final showBadge = item.hasBadge ||
                            (item.badgeCount != null && item.badgeCount! > 0);

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: item.label,
                            hint: 'Navigates to ${item.label}',
                            child: Tooltip(
                              message: item.label,
                              child: GestureDetector(
                                onTap: () {
                                  AppHaptics.selectionClick();
                                  onDestinationSelected(index);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  height: 52.0,
                                  alignment: Alignment.center,
                                  child: AnimatedScale(
                                    scale: isSelected ? 1.08 : 1.0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Icon(
                                            iconData,
                                            size: 25.0,
                                            color: isSelected
                                                ? activeIconColor
                                                : inactiveIconColor,
                                          ),
                                        ),
                                        if (showBadge)
                                          Positioned(
                                            top: 3.0,
                                            right: 3.0,
                                            child: _NotificationBadgeDot(
                                              badgeCount: item.badgeCount,
                                              borderColor: navBg,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBadgeDot extends StatelessWidget {
  final int? badgeCount;
  final Color borderColor;

  const _NotificationBadgeDot({
    required this.borderColor,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    const badgeColor = Color(0xFFFF3B30); // iOS-style red dot badge

    if (badgeCount != null && badgeCount! > 0) {
      final countText = badgeCount! > 9 ? '9+' : '$badgeCount';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(100.0),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        constraints: const BoxConstraints(
          minWidth: 14.0,
          minHeight: 14.0,
        ),
        child: Text(
          countText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.0,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      );
    }

    // Default small red circular dot matching reference image
    return Container(
      width: 9.0,
      height: 9.0,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}

