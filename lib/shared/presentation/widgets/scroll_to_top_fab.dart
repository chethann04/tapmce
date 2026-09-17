import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_extensions.dart';

/// Auto-hiding floating button that slides in when scrolled down > 300px for 1-tap scroll to top.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController scrollController;
  final double threshold;

  const ScrollToTopFab({
    super.key,
    required this.scrollController,
    this.threshold = 300.0,
  });

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController.hasClients) {
      final shouldBeVisible = widget.scrollController.offset > widget.threshold;
      if (shouldBeVisible != _isVisible) {
        setState(() => _isVisible = shouldBeVisible);
      }
    }
  }

  void _scrollToTop() {
    if (widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        0.0,
        duration: AppMotion.normal,
        curve: AppMotion.emphasizedEasing,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final fabBg = brandTheme?.brassPrimary ?? const Color(0xFFC89446);
    final fabFg = brandTheme?.onBrass ?? Colors.white;

    if (AppMotion.isReducedMotion(context)) {
      if (!_isVisible) return const SizedBox.shrink();
      return FloatingActionButton.small(
        onPressed: _scrollToTop,
        backgroundColor: fabBg,
        foregroundColor: fabFg,
        child: const Icon(Icons.arrow_upward_rounded),
      );
    }

    return AnimatedPositioned(
      duration: AppMotion.normal,
      curve: AppMotion.emphasizedEasing,
      bottom: _isVisible ? 90.0 : -60.0,
      right: 20.0,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: _isVisible ? 1.0 : 0.0,
        child: FloatingActionButton.small(
          onPressed: _scrollToTop,
          backgroundColor: fabBg,
          foregroundColor: fabFg,
          elevation: isDark ? 4.0 : 2.0,
          child: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
    );
  }
}
