import 'package:flutter/material.dart';

/// Extended brand theme properties for custom widgets.
@immutable
class AppBrandTheme extends ThemeExtension<AppBrandTheme> {
  final Color brassPrimary;
  final Color brassSoft;
  final Color brassA;
  final Color brassB;
  final Color onBrass;
  final Color roleAccent;
  final Color statusApplied;
  final Color statusShortlisted;
  final Color statusRejected;
  final Color statusPending;
  final Color cardBorder;
  final Color surfaceAlt;
  final Color textMuted;
  final Color dividerColor;
  final LinearGradient brassGradient;
  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;
  final List<BoxShadow> shadow3;

  const AppBrandTheme({
    required this.brassPrimary,
    required this.brassSoft,
    required this.brassA,
    required this.brassB,
    required this.onBrass,
    required this.roleAccent,
    required this.statusApplied,
    required this.statusShortlisted,
    required this.statusRejected,
    required this.statusPending,
    required this.cardBorder,
    required this.surfaceAlt,
    required this.textMuted,
    required this.dividerColor,
    required this.brassGradient,
    required this.shadow1,
    required this.shadow2,
    required this.shadow3,
  });

  @override
  AppBrandTheme copyWith({
    Color? brassPrimary,
    Color? brassSoft,
    Color? brassA,
    Color? brassB,
    Color? onBrass,
    Color? roleAccent,
    Color? statusApplied,
    Color? statusShortlisted,
    Color? statusRejected,
    Color? statusPending,
    Color? cardBorder,
    Color? surfaceAlt,
    Color? textMuted,
    Color? dividerColor,
    LinearGradient? brassGradient,
    List<BoxShadow>? shadow1,
    List<BoxShadow>? shadow2,
    List<BoxShadow>? shadow3,
  }) {
    return AppBrandTheme(
      brassPrimary: brassPrimary ?? this.brassPrimary,
      brassSoft: brassSoft ?? this.brassSoft,
      brassA: brassA ?? this.brassA,
      brassB: brassB ?? this.brassB,
      onBrass: onBrass ?? this.onBrass,
      roleAccent: roleAccent ?? this.roleAccent,
      statusApplied: statusApplied ?? this.statusApplied,
      statusShortlisted: statusShortlisted ?? this.statusShortlisted,
      statusRejected: statusRejected ?? this.statusRejected,
      statusPending: statusPending ?? this.statusPending,
      cardBorder: cardBorder ?? this.cardBorder,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textMuted: textMuted ?? this.textMuted,
      dividerColor: dividerColor ?? this.dividerColor,
      brassGradient: brassGradient ?? this.brassGradient,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
      shadow3: shadow3 ?? this.shadow3,
    );
  }

  @override
  AppBrandTheme lerp(ThemeExtension<AppBrandTheme>? other, double t) {
    if (other is! AppBrandTheme) return this;
    return AppBrandTheme(
      brassPrimary: Color.lerp(brassPrimary, other.brassPrimary, t)!,
      brassSoft: Color.lerp(brassSoft, other.brassSoft, t)!,
      brassA: Color.lerp(brassA, other.brassA, t)!,
      brassB: Color.lerp(brassB, other.brassB, t)!,
      onBrass: Color.lerp(onBrass, other.onBrass, t)!,
      roleAccent: Color.lerp(roleAccent, other.roleAccent, t)!,
      statusApplied: Color.lerp(statusApplied, other.statusApplied, t)!,
      statusShortlisted: Color.lerp(statusShortlisted, other.statusShortlisted, t)!,
      statusRejected: Color.lerp(statusRejected, other.statusRejected, t)!,
      statusPending: Color.lerp(statusPending, other.statusPending, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      brassGradient: LinearGradient.lerp(brassGradient, other.brassGradient, t)!,
      shadow1: t < 0.5 ? shadow1 : other.shadow1,
      shadow2: t < 0.5 ? shadow2 : other.shadow2,
      shadow3: t < 0.5 ? shadow3 : other.shadow3,
    );
  }
}
