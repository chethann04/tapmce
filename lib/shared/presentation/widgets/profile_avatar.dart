import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extensions.dart';

enum ProfileAvatarSize {
  small(radius: 18, fontSize: 13, iconSize: 18),
  medium(radius: 22, fontSize: 15, iconSize: 22),
  large(radius: 36, fontSize: 24, iconSize: 34),
  xlarge(radius: 46, fontSize: 32, iconSize: 44),
  hero(radius: 54, fontSize: 38, iconSize: 52);

  final double radius;
  final double fontSize;
  final double iconSize;

  const ProfileAvatarSize({
    required this.radius,
    required this.fontSize,
    required this.iconSize,
  });
}

/// Unified, accessible user avatar component for Placement Connect.
///
/// Priority rendering sequence:
/// 1. Remote Profile Image (`imageUrl` or `photoUrl`)
/// 2. User Initials (`name` initials extracted cleanly)
/// 3. Generic Person Icon
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? photoUrl;
  final String? name;
  final ProfileAvatarSize size;
  final double? customRadius;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final Widget? badge;
  final String? semanticsLabel;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.photoUrl,
    this.name,
    this.size = ProfileAvatarSize.medium,
    this.customRadius,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
    this.backgroundColor,
    this.textStyle,
    this.badge,
    this.semanticsLabel,
  });

  String? get _effectiveUrl {
    final url = (imageUrl ?? photoUrl)?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  double get _radius => customRadius ?? size.radius;
  double get _diameter => _radius * 2;

  String _extractInitials(String? rawName) {
    if (rawName == null) return '';
    final clean = rawName.trim();
    if (clean.isEmpty) return '';

    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final effectiveUrl = _effectiveUrl;
    final initials = _extractInitials(name);
    final effectiveLabel = semanticsLabel ?? (name != null && name!.isNotEmpty ? '$name profile picture' : 'User profile picture');

    Widget avatarContent;

    if (effectiveUrl != null) {
      avatarContent = Image.network(
        effectiveUrl,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingFallback(brandTheme);
        },
        errorBuilder: (context, error, stackTrace) {
          // Graceful fallback to initials or generic icon if network error occurs
          return _buildInitialsOrIconFallback(initials, brandTheme, theme);
        },
      );
    } else {
      avatarContent = _buildInitialsOrIconFallback(initials, brandTheme, theme);
    }

    Widget avatarWidget = ClipOval(
      child: Container(
        width: _diameter,
        height: _diameter,
        color: backgroundColor ?? (brandTheme?.brassSoft ?? theme.colorScheme.primaryContainer),
        child: avatarContent,
      ),
    );

    if (showBorder) {
      final effectiveBorderColor = borderColor ?? (brandTheme?.brassPrimary.withValues(alpha: 0.6) ?? theme.colorScheme.primary);
      avatarWidget = Container(
        width: _diameter + (borderWidth * 2),
        height: _diameter + (borderWidth * 2),
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
        ),
        child: avatarWidget,
      );
    }

    if (badge != null) {
      avatarWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: 0,
            bottom: 0,
            child: badge!,
          ),
        ],
      );
    }

    if (onTap != null) {
      avatarWidget = InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatarWidget,
      );
    }

    return Semantics(
      label: effectiveLabel,
      image: true,
      button: onTap != null,
      child: avatarWidget,
    );
  }

  Widget _buildLoadingFallback(AppBrandTheme? brandTheme) {
    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        gradient: brandTheme?.brassGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: _radius * 0.7,
          height: _radius * 0.7,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: brandTheme?.onBrass ?? Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsOrIconFallback(String initials, AppBrandTheme? brandTheme, ThemeData theme) {
    if (initials.isNotEmpty) {
      final style = textStyle ??
          GoogleFonts.fraunces(
            fontSize: customRadius != null ? (customRadius! * 0.7) : size.fontSize,
            fontWeight: FontWeight.w700,
            color: brandTheme?.onBrass ?? Colors.white,
          );

      return Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          gradient: brandTheme?.brassGradient ??
              LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials,
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: brandTheme?.brassSoft ?? theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: customRadius != null ? (customRadius! * 0.9) : size.iconSize,
          color: brandTheme?.brassPrimary ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}
