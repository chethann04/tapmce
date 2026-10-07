import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized responsive breakpoint definition for Placement Connect.
///
/// Breakpoint tiers:
/// - Compact (<360dp): Small/older phones (e.g., iPhone SE, older Androids)
/// - Normal (360–399dp): Standard modern phones
/// - Large (400–599dp): Large phones, Phablets, Max-class devices
/// - Tablet (600dp+): Tablets, foldables, and large screen surfaces
class AppBreakpoints {
  AppBreakpoints._();

  static const double compactMax = 359.0;
  static const double normalMin = 360.0;
  static const double normalMax = 399.0;
  static const double largeMin = 400.0;
  static const double largeMax = 599.0;
  static const double tabletMin = 600.0;

  static const double maxContentWidth = 720.0;
  static const double maxModalWidth = 560.0;
}

/// Convenience extension on [BuildContext] for clean, performant responsive queries.
extension AppResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  EdgeInsets get safePadding => MediaQuery.paddingOf(this);
  double get safeTop => MediaQuery.paddingOf(this).top;
  double get safeBottom => MediaQuery.paddingOf(this).bottom;
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardHeight > 0;

  bool get isCompact => screenWidth < AppBreakpoints.normalMin;
  bool get isNormal => screenWidth >= AppBreakpoints.normalMin && screenWidth < AppBreakpoints.largeMin;
  bool get isLarge => screenWidth >= AppBreakpoints.largeMin && screenWidth < AppBreakpoints.tabletMin;
  bool get isTablet => screenWidth >= AppBreakpoints.tabletMin;

  /// Responsive horizontal page padding.
  double get responsiveHorizontalPadding {
    if (isCompact) return 14.0;
    if (isTablet) return 32.0;
    return 20.0;
  }

  /// Safe bottom padding for scrollable views above the floating pill navigation bar.
  /// Dynamically accounts for device gesture navigation, 3-button nav, and safe bottom insets.
  double get navBarBottomPadding {
    return math.max(120.0, safeBottom + 85.0);
  }

  /// Selects a responsive value according to the current screen tier.
  T responsive<T>({
    required T compact,
    required T normal,
    T? large,
    T? tablet,
  }) {
    if (isTablet && tablet != null) return tablet;
    if (isLarge && large != null) return large;
    if (isCompact) return compact;
    return normal;
  }
}
