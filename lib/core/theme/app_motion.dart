import 'package:flutter/material.dart';

/// Centralized app-wide motion system tokens, curves, and reduced-motion helpers.
class AppMotion {
  AppMotion._();

  // Duration Tokens
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  // Legacy & specific component tokens
  static const Duration staggerDelay = Duration(milliseconds: 40);
  static const Duration riseDuration = Duration(milliseconds: 320);
  static const Duration transitionDuration = Duration(milliseconds: 200);
  static const Duration navExpandDuration = Duration(milliseconds: 200);
  static const Duration statusThreadDuration = Duration(milliseconds: 350);
  static const Duration shimmerDuration = Duration(milliseconds: 1200);

  // Easing Curves
  static const Curve standardEasing = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve emphasizedEasing = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve springEasing = Cubic(0.34, 1.4, 0.64, 1.0);

  /// Returns true if the user's OS has requested reduced motion.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Returns the provided duration, or [Duration.zero] if reduced motion is enabled.
  static Duration duration(BuildContext context, Duration defaultDuration) {
    return isReducedMotion(context) ? Duration.zero : defaultDuration;
  }
}


