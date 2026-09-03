import 'package:flutter/material.dart';
import 'package:placement_connect/core/theme/theme_extensions.dart';
import 'package:placement_connect/core/theme/app_spacing.dart';
import 'package:placement_connect/core/theme/app_motion.dart';

class StatusNodeData {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final VoidCallback? onTap;

  const StatusNodeData({
    required this.label,
    this.isDone = false,
    this.isCurrent = false,
    this.onTap,
  });
}

class StatusThreadWidget extends StatefulWidget {
  final List<StatusNodeData> nodes;

  const StatusThreadWidget({
    super.key,
    required this.nodes,
  });

  @override
  State<StatusThreadWidget> createState() => _StatusThreadWidgetState();
}

class _StatusThreadWidgetState extends State<StatusThreadWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.statusThreadDuration,
      vsync: this,
    );

    double progress = 0.0;
    if (widget.nodes.length > 1) {
      int lastIndex = 0;
      for (int i = 0; i < widget.nodes.length; i++) {
        if (widget.nodes[i].isDone || widget.nodes[i].isCurrent) {
          lastIndex = i;
        }
      }
      progress = lastIndex / (widget.nodes.length - 1);
    }

    _fillAnimation = Tween<double>(begin: 0.0, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standardEasing),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant StatusThreadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    double progress = 0.0;
    if (widget.nodes.length > 1) {
      int lastIndex = 0;
      for (int i = 0; i < widget.nodes.length; i++) {
        if (widget.nodes[i].isDone || widget.nodes[i].isCurrent) {
          lastIndex = i;
        }
      }
      progress = lastIndex / (widget.nodes.length - 1);
    }
    _fillAnimation = Tween<double>(begin: _fillAnimation.value, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standardEasing),
    );
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = widget.nodes.length;
        // Dynamically compute nodeWidth so 4 nodes fit inside compact hero tiles without overflow
        final nodeItemWidth = (totalWidth / (count > 0 ? count : 1)).clamp(24.0, 60.0);
        final availableTrackWidth = (totalWidth - nodeItemWidth).clamp(0.0, double.infinity);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: Stack(
                children: [
                  // Track
                  Positioned(
                    top: 11,
                    left: nodeItemWidth / 2,
                    right: nodeItemWidth / 2,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: brandTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Fill bar
                  AnimatedBuilder(
                    animation: _fillAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 11,
                        left: nodeItemWidth / 2,
                        child: Container(
                          width: availableTrackWidth * _fillAnimation.value,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: brandTheme.brassGradient,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: brandTheme.brassSoft,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Nodes
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: widget.nodes.map((node) {
                        return SizedBox(
                          width: nodeItemWidth,
                          child: Center(
                            child: _buildNodeDot(context, node, brandTheme),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sp1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.nodes.map((node) {
                final isHighlight = node.isDone || node.isCurrent;
                return SizedBox(
                  width: nodeItemWidth,
                  child: _BlinkingNodeText(
                    node: node,
                    isHighlight: isHighlight,
                    totalWidth: totalWidth,
                    brandTheme: brandTheme,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNodeDot(
      BuildContext context, StatusNodeData node, AppBrandTheme brandTheme) {
    if (node.isDone) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: brandTheme.brassGradient,
        ),
      );
    } else if (node.isCurrent) {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: brandTheme.brassPrimary, width: 2),
          boxShadow: [
            BoxShadow(
              color: brandTheme.brassSoft,
              blurRadius: 0,
              spreadRadius: 3,
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: brandTheme.cardBorder, width: 2),
        ),
      );
    }
  }
}

class _BlinkingNodeText extends StatefulWidget {
  final StatusNodeData node;
  final bool isHighlight;
  final double totalWidth;
  final AppBrandTheme brandTheme;

  const _BlinkingNodeText({
    required this.node,
    required this.isHighlight,
    required this.totalWidth,
    required this.brandTheme,
  });

  @override
  State<_BlinkingNodeText> createState() => _BlinkingNodeTextState();
}

class _BlinkingNodeTextState extends State<_BlinkingNodeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _triggerBlink() {
    _blinkController.forward().then((_) => _blinkController.reverse());
    if (widget.node.onTap != null) {
      widget.node.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _triggerBlink,
      behavior: HitTestBehavior.opaque,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: Text(
          widget.node.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: widget.totalWidth < 180 ? 8.5 : 10,
            fontWeight: FontWeight.w700,
            color: widget.isHighlight
                ? theme.colorScheme.onSurface
                : widget.brandTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
