import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_extensions.dart';

enum ToastType { success, error, info }

/// Floating pill toast notification displaying top-center overlays with slide-down entrance.
class AppToast {
  AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
        displayDuration: duration,
      ),
    );

    overlayState.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration displayDuration;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.displayDuration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.emphasizedEasing),
    );

    _controller.forward();

    Future.delayed(widget.displayDuration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final isDark = theme.brightness == Brightness.dark;

    IconData iconData;
    Color iconColor;

    switch (widget.type) {
      case ToastType.success:
        iconData = Icons.check_circle_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case ToastType.error:
        iconData = Icons.error_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      case ToastType.info:
        iconData = Icons.info_rounded;
        iconColor = brandTheme?.brassPrimary ?? const Color(0xFF3B82F6);
        break;
    }

    final toastBg = isDark ? const Color(0xFF1E2026) : Colors.white;
    final toastBorder = isDark ? const Color(0xFF2C2E38) : Colors.black.withValues(alpha: 0.08);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12.0,
      left: 20.0,
      right: 20.0,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 11.0),
              decoration: BoxDecoration(
                color: toastBg,
                borderRadius: BorderRadius.circular(100.0),
                border: Border.all(color: toastBorder, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                    blurRadius: 20.0,
                    spreadRadius: 0.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: iconColor, size: 20.0),
                  const SizedBox(width: 10.0),
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
