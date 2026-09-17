import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';

/// Smooth count-up animation widget for dashboard metrics (integers or decimals).
class AnimatedCounter extends StatelessWidget {
  final num targetValue;
  final int fractionDigits;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.targetValue,
    this.fractionDigits = 0,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      final formatted = targetValue.toStringAsFixed(fractionDigits);
      return Text('$prefix$formatted$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue.toDouble()),
      duration: duration,
      curve: AppMotion.emphasizedEasing,
      builder: (context, val, child) {
        final formatted = fractionDigits == 0
            ? val.round().toString()
            : val.toStringAsFixed(fractionDigits);
        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
      },
    );
  }
}
