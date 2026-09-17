import 'package:flutter/services.dart';

/// Centralized tactile haptic feedback system for Placement Connect.
class AppHaptics {
  AppHaptics._();

  /// Light subtle feedback (tab bar item switch, toggle change)
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium tactile feedback (button presses, card taps)
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy feedback (destructive actions, error states)
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click feedback (chip select, radio selection)
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Success vibration pattern
  static Future<void> successVibration() async {
    await HapticFeedback.vibrate();
  }
}
