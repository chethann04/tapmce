import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_extensions.dart';

/// Form text input with animated focus glow border & smooth error text fade-in.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _validate(String? value) {
    if (widget.validator != null) {
      final err = widget.validator!(value);
      if (err != _errorText) {
        setState(() => _errorText = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = brandTheme.brassPrimary;
    final borderColor = _errorText != null
        ? brandTheme.statusRejected
        : (_isFocused
            ? primaryColor
            : (isDark ? const Color(0xFF2C2E38) : brandTheme.cardBorder));

    final isReduced = AppMotion.isReducedMotion(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            color: _isFocused ? primaryColor : brandTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6.0),

        // Glowing Focus Border Container
        isReduced
            ? Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: borderColor, width: _isFocused ? 1.5 : 1.0),
                ),
                child: _buildInput(theme, brandTheme),
              )
            : AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.easeOutCubic,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: borderColor, width: _isFocused ? 1.5 : 1.0),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.20),
                            blurRadius: 10.0,
                            spreadRadius: 1.0,
                          ),
                        ]
                      : null,
                ),
                child: _buildInput(theme, brandTheme),
              ),

        // Smooth Validation Error Text Fade-In
        if (_errorText != null) ...[
          const SizedBox(height: 4.0),
          isReduced
              ? Text(
                  _errorText!,
                  style: TextStyle(fontSize: 11.0, color: brandTheme.statusRejected),
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOutCubic,
                  builder: (context, val, child) {
                    return Opacity(
                      opacity: val,
                      child: child,
                    );
                  },
                  child: Text(
                    _errorText!,
                    style: TextStyle(fontSize: 11.0, color: brandTheme.statusRejected),
                  ),
                ),
        ],
      ],
    );
  }

  Widget _buildInput(ThemeData theme, AppBrandTheme brandTheme) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      onChanged: (val) {
        _validate(val);
        widget.onChanged?.call(val);
      },
      validator: (val) {
        final err = widget.validator?.call(val);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && err != _errorText) {
            setState(() => _errorText = err);
          }
        });
        return err;
      },
      style: TextStyle(fontSize: 14.0, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(fontSize: 13.0, color: brandTheme.textMuted),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20.0, color: _isFocused ? brandTheme.brassPrimary : brandTheme.textMuted)
            : null,
        suffixIcon: widget.suffixIcon,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        errorStyle: const TextStyle(height: 0, fontSize: 0), // Handled by custom Animated error text
      ),
    );
  }
}
