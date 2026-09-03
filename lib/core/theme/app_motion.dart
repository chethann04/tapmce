import 'package:flutter/material.dart';

/// App-wide motion duration and curve tokens.
class AppMotion {
  AppMotion._();

  static const Duration staggerDelay = Duration(milliseconds: 60);
  static const Duration riseDuration = Duration(milliseconds: 550);
  static const Duration transitionDuration = Duration(milliseconds: 220);
  static const Duration navExpandDuration = Duration(milliseconds: 280);
  static const Duration statusThreadDuration = Duration(milliseconds: 500);
  static const Duration shimmerDuration = Duration(milliseconds: 1400);

  static const Curve standardEasing = Cubic(0.2, 0.8, 0.2, 1.0);
}
