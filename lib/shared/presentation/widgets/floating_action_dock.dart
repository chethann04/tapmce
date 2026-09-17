import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_haptics.dart';

class DockItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Floating multi-action dock positioned above the bottom navigation bar.
class FloatingActionDock extends StatelessWidget {
  final List<DockItem> actions;

  const FloatingActionDock({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusPill),
        border: Border.all(color: brandTheme.cardBorder),
        boxShadow: brandTheme.shadow2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                AppHaptics.mediumImpact();
                item.onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: brandTheme.brassSoft,
                  borderRadius: BorderRadius.circular(AppShapes.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 16, color: brandTheme.brassPrimary),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: brandTheme.brassPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
