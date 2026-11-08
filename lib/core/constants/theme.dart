import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData getAppTheme() {
  return ThemeData(
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: AppColors.primary,
    dividerColor: AppColors.divider,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.glassCard,
      background: AppColors.background,
    ),
    cardTheme: CardThemeData(
      color: AppColors.glassCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.glassBorder, width: 1),
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textMain,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textMain,
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: AppColors.primary,
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: GoogleFonts.nunito(color: AppColors.textSecondary),
      hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
    ),
    textTheme: TextTheme(
      // Friendly, modern rounded sans (Nunito)
      displayLarge: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textMain),
      displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textMain),
      displaySmall: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textMain),
      headlineLarge: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMain),
      headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textMain),
      titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textMain),
      titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMain),
      titleSmall: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),

      bodyLarge: GoogleFonts.nunito(fontSize: 16, color: AppColors.textMain, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, color: AppColors.textMain, fontWeight: FontWeight.w500),
      bodySmall: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
      labelMedium: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    ),
  );
}
