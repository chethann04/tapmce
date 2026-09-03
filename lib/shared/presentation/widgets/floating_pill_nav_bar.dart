import 'package:flutter/material.dart';
import 'package:placement_connect/core/theme/theme_extensions.dart';
import 'package:placement_connect/core/theme/app_spacing.dart';
import 'package:placement_connect/core/theme/app_motion.dart';

class NavDestinationItem {
  final IconData icon;
  final String label;

  const NavDestinationItem({required this.icon, required this.label});
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
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final isDark = theme.brightness == Brightness.dark;

    final navBg = isDark ? const Color(0xFF0B0C0E) : theme.colorScheme.surface;
    final itemBg = isDark ? const Color(0xFF26282D) : brandTheme.surfaceAlt;
    final navBorder = isDark ? const Color(0xFF242529) : brandTheme.cardBorder;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: AppSpacing.sp4,
      right: AppSpacing.sp4,
      bottom: AppSpacing.sp3 + bottomInset,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sp2),
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(AppShapes.radiusPill),
          border: Border.all(color: navBorder),
          boxShadow: brandTheme.shadow3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final isSelected = index == selectedIndex;
            final item = items[index];

            return Expanded(
              flex: isSelected ? 2 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: GestureDetector(
                  onTap: () => onDestinationSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppMotion.navExpandDuration,
                    curve: AppMotion.standardEasing,
                    height: 44,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? AppSpacing.sp3 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppShapes.radiusPill),
                      gradient: isSelected ? brandTheme.brassGradient : null,
                      color: isSelected ? null : itemBg,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: brandTheme.brassSoft,
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppShapes.radiusPill),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 19,
                            color: isSelected
                                ? brandTheme.onBrass
                                : theme.colorScheme.onSurface,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: isSelected ? 1.0 : 0.0,
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: brandTheme.onBrass,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
