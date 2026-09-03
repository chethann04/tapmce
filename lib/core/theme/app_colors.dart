import 'package:flutter/material.dart';

/// App-wide color constants matching `master_prompt_3_polish_final.md` and `placement_connect_premium_final.html`.
class AppColors {
  AppColors._();

  // ── Light Theme Tokens ──────────────────────────────────────────────────
  static const lightBg = Color(0xFFF1F2F4);
  static const lightSurface1 = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFE9EAEC);
  static const lightInk = Color(0xFF14171C);
  static const lightInkMuted = Color(0xFF5B6472);
  static const lightBorder = Color(0xFFDADCE1);

  static const lightBrassA = Color(0xFFC89446);
  static const lightBrassB = Color(0xFF8B5E1E);
  static const lightBrass = Color(0xFFA9752F);
  static const lightBrassSoft = Color(0x24A9752F); // rgba(169,117,47,.14)
  static const lightOnBrass = Color(0xFFFFFFFF);

  static const lightSuccess = Color(0xFF2F6B4F);
  static const lightSuccessSoft = Color(0x1F2F6B4F); // rgba(47,107,79,.12)
  static const lightAlert = Color(0xFFB33F3A);
  static const lightAlertSoft = Color(0x1FB33F3A); // rgba(179,63,58,.12)
  static const lightInfo = Color(0xFF3E5C76);
  static const lightInfoSoft = Color(0x1F3E5C76); // rgba(62,92,118,.12)

  // Light Shadows
  static const lightShadow1 = [
    BoxShadow(color: Color(0x0D14171C), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x0D14171C), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const lightShadow2 = [
    BoxShadow(color: Color(0x1A14171C), offset: Offset(0, 10), blurRadius: 24),
    BoxShadow(color: Color(0x1A14171C), offset: Offset(0, 24), blurRadius: 48),
  ];
  static const lightShadow3 = [
    BoxShadow(color: Color(0x2914171C), offset: Offset(0, 20), blurRadius: 50),
  ];

  // Divider
  static const lightDivider = Color(0x1F14171C); // ~12% opacity of dark ink on light surface

  // ── Dark Theme Tokens (True OLED #000000) ────────────────────────────────
  static const darkBg = Color(0xFF000000);
  static const darkSurface1 = Color(0xFF121316); // Elevation 1
  static const darkSurface2 = Color(0xFF1E2024); // Elevation 2
  static const darkInk = Color(0xFFF2F1EC);
  static const darkInkMuted = Color(0xFF9AA3AF);
  static const darkBorder = Color(0xFF26282D);

  static const darkBrassA = Color(0xFFD9A758);
  static const darkBrassB = Color(0xFFA9752F);
  static const darkBrass = Color(0xFFC89446);
  static const darkBrassSoft = Color(0x33C89446); // rgba(200,148,70,.2)
  static const darkOnBrass = Color(0xFF0A0A0B);

  static const darkSuccess = Color(0xFF4C9172);
  static const darkSuccessSoft = Color(0x294C9172); // rgba(76,145,114,.16)
  static const darkAlert = Color(0xFFD6635D);
  static const darkAlertSoft = Color(0x29D6635D); // rgba(214,99,93,.16)
  static const darkInfo = Color(0xFF6C8FB0);
  static const darkInfoSoft = Color(0x296C8FB0); // rgba(108,143,176,.16)

  // Dark Shadows
  static const darkShadow1 = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 2), blurRadius: 4),
  ];
  static const darkShadow2 = [
    BoxShadow(color: Color(0xA6000000), offset: Offset(0, 20), blurRadius: 50),
  ];
  static const darkShadow3 = [
    BoxShadow(color: Color(0xBF000000), offset: Offset(0, 24), blurRadius: 60),
  ];

  // Divider
  static const darkDivider = Color(0x1AF2F1EC); // ~10% opacity of light ink on dark surface

  // Gradients
  static const lightBrassGradient = LinearGradient(
    colors: [lightBrassA, lightBrassB],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkBrassGradient = LinearGradient(
    colors: [darkBrassA, darkBrassB],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
