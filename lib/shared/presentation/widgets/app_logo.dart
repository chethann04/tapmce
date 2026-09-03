import 'package:flutter/material.dart';

/// Reusable MCE Crest Logo widget displaying the official gold emblem.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showGlow = false,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/mce_logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              child: Icon(
                Icons.school_rounded,
                size: size * 0.5,
                color: const Color(0xFFD4AF37),
              ),
            );
          },
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
