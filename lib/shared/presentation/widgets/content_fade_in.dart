import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';

/// Smooth fade-in wrapper for asynchronous content once skeleton loader completes.
class ContentFadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const ContentFadeIn({
    super.key,
    required this.child,
    this.duration = AppMotion.normal,
    this.curve = AppMotion.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: child,
    );
  }
}
