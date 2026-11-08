import 'package:flutter/material.dart';

class AppColors {
  // Soft Pastel Canvas Gradient (Matching App Logo Blue #347AE2)
  static const Color brandBlue = Color(0xFF347AE2);     // Logo Royal Blue (#347AE2)
  static const Color gradientStart = Color(0xFFE2EDFC); // Soft Logo Sky Blue
  static const Color gradientEnd = Color(0xFFEDF4FE);   // Soft Ice Blue Tint
  static const Color background = Color(0xFFF3F7FD);   // Soft pastel blue fallback

  // Active Accent & Primary (Logo Royal Blue #347AE2)
  static const Color primary = Color(0xFF347AE2);
  static const Color primaryPill = Color(0xFF347AE2);
  static const Color onPrimary = Colors.white;

  // Frosted Glass Surfaces
  static const Color glassCard = Color(0xF5FFFFFF);     // ~96% white glass
  static const Color glassCardDarker = Color(0xEEF8FAFC);
  static const Color glassBorder = Color(0x66E2E8F0);

  // Verification & Status Badges
  static const Color verifiedGreen = Color(0xFF15803D);
  static const Color verifiedBg = Color(0xFFDCFCE7);
  static const Color alertRed = Color(0xFFB91C1C);
  static const Color alertBg = Color(0xFFFEE2E2);

  // Neutral Pills & Chips
  static const Color neutralPill = Color(0xFFF1F5F9);
  static const Color neutralPillText = Color(0xFF334155);

  // Typography & Content
  static const Color textMain = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF55555C);
  static const Color textMuted = Color(0xFF8E8E93);
  static const Color divider = Color(0xFFE2E8F0);

  // Gradient BoxDecoration Helper
  static const BoxDecoration backgroundGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientStart, gradientEnd],
    ),
  );
}
