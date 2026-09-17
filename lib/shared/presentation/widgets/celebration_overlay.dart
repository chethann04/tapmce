import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';

/// Lightweight particle celebration burst overlay for offers, shortlists, & drive creation milestones.
class CelebrationOverlay {
  CelebrationOverlay._();

  static void show(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) return;

    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ConfettiBurstWidget(
        onComplete: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlayState.insert(entry);
  }
}

class _ConfettiBurstWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const _ConfettiBurstWidget({required this.onComplete});

  @override
  State<_ConfettiBurstWidget> createState() => _ConfettiBurstWidgetState();
}

class _ConfettiBurstWidgetState extends State<_ConfettiBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  static const _colors = [
    Color(0xFFC89446), // Brand Gold
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Sapphire
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    final rng = math.Random();
    _particles = List.generate(42, (index) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = 120.0 + rng.nextDouble() * 280.0;
      return _Particle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed - 80.0,
        radius: 3.0 + rng.nextDouble() * 4.0,
        color: _colors[rng.nextInt(_colors.length)],
        rotation: rng.nextDouble() * math.pi,
      );
    });

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final center = Offset(screenSize.width / 2, screenSize.height * 0.4);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return CustomPaint(
            size: screenSize,
            painter: _ParticlePainter(
              particles: _particles,
              progress: progress,
              center: center,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double dx;
  final double dy;
  final double radius;
  final Color color;
  final double rotation;

  _Particle({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.color,
    required this.rotation,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);
    final gravity = progress * progress * 200.0;

    for (final p in particles) {
      final pos = Offset(
        center.dx + (p.dx * progress),
        center.dy + (p.dy * progress) + gravity,
      );

      final paint = Paint()
        ..color = p.color.withValues(alpha: fadeOut * 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pos, p.radius * (1.0 - (progress * 0.4)), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
