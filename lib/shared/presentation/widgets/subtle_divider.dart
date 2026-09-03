import 'package:flutter/material.dart';

import '../../../core/theme/theme_extensions.dart';

/// A consistent, subtle divider that uses the brand theme's divider color.
///
/// Replaces all hardcoded `Divider()` widgets across the app with a
/// soft, low-opacity separator that works well on both light and dark surfaces.
class SubtleDivider extends StatelessWidget {
  /// Height (total vertical space including the divider line).
  final double height;

  /// Left inset indent.
  final double? indent;

  /// Right inset indent.
  final double? endIndent;

  /// Optional custom color override. If null, uses brand theme's dividerColor.
  final Color? color;

  /// Divider thickness in logical pixels.
  final double thickness;

  const SubtleDivider({
    super.key,
    this.height = 1,
    this.indent,
    this.endIndent,
    this.color,
    this.thickness = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final brandTheme = Theme.of(context).extension<AppBrandTheme>();
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color ?? brandTheme?.dividerColor,
    );
  }
}
