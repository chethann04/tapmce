import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_extensions.dart';

/// Interactive progress bar visualizing recruitment stages with animated connecting lines & glowing nodes.
class AnimatedStageProgress extends StatelessWidget {
  final List<String> stages;
  final int currentStageIndex;

  const AnimatedStageProgress({
    super.key,
    required this.stages,
    required this.currentStageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final isDark = theme.brightness == Brightness.dark;

    final progressRatio = stages.length > 1
        ? (currentStageIndex / (stages.length - 1)).clamp(0.0, 1.0)
        : 1.0;

    return Column(
      children: [
        SizedBox(
          height: 36.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Base Line Track
                  Container(
                    height: 4.0,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),

                  // Animated Active Progress Fill Line
                  if (!AppMotion.isReducedMotion(context))
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: progressRatio),
                      duration: AppMotion.slow,
                      curve: AppMotion.emphasizedEasing,
                      builder: (context, val, child) {
                        return Container(
                          height: 4.0,
                          width: totalWidth * val,
                          decoration: BoxDecoration(
                            gradient: brandTheme.brassGradient,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      height: 4.0,
                      width: totalWidth * progressRatio,
                      decoration: BoxDecoration(
                        gradient: brandTheme.brassGradient,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),

                  // Stage Nodes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(stages.length, (index) {
                      final isPassed = index <= currentStageIndex;
                      final isCurrent = index == currentStageIndex;

                      final nodeColor = isPassed
                          ? brandTheme.brassPrimary
                          : (isDark ? const Color(0xFF3A3D4A) : const Color(0xFFCBD5E1));

                      return AnimatedContainer(
                        duration: AppMotion.fast,
                        width: isCurrent ? 24.0 : 18.0,
                        height: isCurrent ? 24.0 : 18.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPassed ? nodeColor : theme.colorScheme.surface,
                          border: Border.all(
                            color: nodeColor,
                            width: isCurrent ? 3.0 : 2.0,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: brandTheme.brassPrimary.withValues(alpha: 0.4),
                                    blurRadius: 10.0,
                                    spreadRadius: 2.0,
                                  ),
                                ]
                              : null,
                        ),
                        child: isPassed && !isCurrent
                            ? const Icon(Icons.check_rounded, size: 10.0, color: Colors.white)
                            : null,
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 8.0),

        // Stage Labels Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stages.length, (index) {
            final isCurrent = index == currentStageIndex;
            return Expanded(
              child: Text(
                stages[index],
                textAlign: index == 0
                    ? TextAlign.left
                    : (index == stages.length - 1 ? TextAlign.right : TextAlign.center),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? brandTheme.brassPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
