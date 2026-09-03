import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// BentoCard providing scale-on-press micro-interaction and tactile feedback.
class BentoCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final ShapeBorder? shape;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double scaleFactor;

  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.shape,
    this.color,
    this.padding,
    this.scaleFactor = 0.97,
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticFeedback.selectionClick();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: ShapeDecoration(
            color: widget.color ?? Theme.of(context).colorScheme.surface,
            shape: widget.shape ?? const RoundedRectangleBorder(),
          ),
          child: content,
        ),
      ),
    );
  }
}
