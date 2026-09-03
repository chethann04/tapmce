import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';

/// Signature PlacementConnect component: Glassmorphic card with a vertical status pillar.
class StatusPillarCard extends StatelessWidget {
  final Widget child;
  final Color? pillarColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const StatusPillarCard({
    super.key,
    required this.child,
    this.pillarColor,
    this.onTap,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final accentColor = pillarColor ?? brandTheme?.roleAccent ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: brandTheme?.cardBorder ?? theme.colorScheme.outlineVariant,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Signature Status Pillar Bar
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: padding,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
