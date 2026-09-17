import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_motion.dart';

/// Wave-staggered shimmer loading state for cards & list items.
class StaggeredShimmerLoader extends StatefulWidget {
  final int itemCount;
  final double itemHeight;

  const StaggeredShimmerLoader({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 110.0,
  });

  @override
  State<StaggeredShimmerLoader> createState() => _StaggeredShimmerLoaderState();
}

class _StaggeredShimmerLoaderState extends State<StaggeredShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: AppMotion.shimmerDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark ? brandTheme.surfaceAlt : const Color(0xFFEFEFEF);
    final highlightColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF7F7F7);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sp3),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            // Calculate staggered phase offset per item (staggered wave)
            final phase = (_shimmerController.value + (index * 0.18)) % 1.0;

            return Container(
              height: widget.itemHeight,
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sp4),
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                  side: BorderSide(color: brandTheme.cardBorder),
                ),
              ),
              child: GradientShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                phase: phase,
              ),
            );
          },
        );
      },
    );
  }
}

class GradientShimmerBox extends StatelessWidget {
  final Color baseColor;
  final Color highlightColor;
  final double phase;

  const GradientShimmerBox({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment(-1.5 + (phase * 3.0), -0.3),
          end: Alignment(-0.5 + (phase * 3.0), 0.3),
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 18,
            width: 140,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 180,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
