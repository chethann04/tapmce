import 'package:flutter/material.dart';
import 'package:placement_connect/core/theme/theme_extensions.dart';
import 'package:placement_connect/core/theme/app_spacing.dart';
import 'package:placement_connect/core/theme/app_motion.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppShapes.radiusSmall,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.shimmerDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final baseColor = brandTheme.surfaceAlt;
    final highlightColor = theme.colorScheme.surface;

    final mediaQuery = MediaQuery.of(context);
    final disableAnimations = mediaQuery.accessibleNavigation || mediaQuery.disableAnimations;

    if (disableAnimations) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (_controller.value * 4.0), 0.0),
              end: Alignment(-1.0 + (_controller.value * 4.0), 0.0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCardRow extends StatelessWidget {
  const SkeletonCardRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp3),
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: const Row(
        children: [
          SkeletonLoader(
            width: 44,
            height: 44,
            borderRadius: 14,
          ),
          SizedBox(width: AppSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 140,
                  height: 14,
                  borderRadius: 6,
                ),
                SizedBox(height: AppSpacing.sp2),
                SkeletonLoader(
                  width: 90,
                  height: 10,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
