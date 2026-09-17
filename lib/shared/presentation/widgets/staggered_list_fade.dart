import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';

/// Wraps list items with a staggered 6px translateY + opacity entrance animation.
class StaggeredListFade extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration stepDelay;

  const StaggeredListFade({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = Duration.zero,
    this.stepDelay = AppMotion.staggerDelay,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return child;
    }

    // Cap stagger count at index 5 to prevent long delays on deep scroll
    final clampedIndex = index.clamp(0, 5);
    final delay = baseDelay + (stepDelay * clampedIndex);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppMotion.normal + delay,
      curve: AppMotion.easeOutCubic,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0.0, (1.0 - val) * 6.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
