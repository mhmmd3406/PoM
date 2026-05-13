import 'package:flutter/material.dart';

// PoM brand palette — premium dark
abstract final class AppColors {
  // Backgrounds (layered depth)
  static const bg0 = Color(0xFF0A0A0F); // deepest
  static const bg1 = Color(0xFF12121A); // scaffold
  static const bg2 = Color(0xFF1A1A26); // cards
  static const bg3 = Color(0xFF22223A); // elevated cards / bottom sheet

  // Accent — electric violet
  static const accent = Color(0xFF7C5CFC);
  static const accentLight = Color(0xFF9D80FF);
  static const accentDim = Color(0xFF3D2E80);

  // Semantic
  static const positive = Color(0xFF34D399); // teal-green
  static const warning = Color(0xFFFBBF24);
  static const negative = Color(0xFFF87171);

  // Text
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF9090B0);
  static const textMuted = Color(0xFF505070);

  // Divider / border
  static const border = Color(0xFF2A2A40);

  // Emoji rating palette (1→5 gradient)
  static const List<Color> ratingColors = [
    Color(0xFFF87171), // 1 — red
    Color(0xFFFB923C), // 2 — orange
    Color(0xFFFBBF24), // 3 — amber
    Color(0xFF34D399), // 4 — green
    Color(0xFF7C5CFC), // 5 — violet (elite)
  ];
}

final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg1,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.bg1,
          primary: AppColors.accent,
          secondary: AppColors.accentLight,
          error: AppColors.negative,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary, letterSpacing: -0.3,
          ),
          titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary, letterSpacing: 0.2,
          ),
        ),
        cardTheme: const CardTheme(
          color: AppColors.bg2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.border),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentLight,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppColors.accentDim),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bg2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
          hintStyle: TextStyle(color: AppColors.textMuted),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.bg3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg1,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          iconTheme: IconThemeData(color: AppColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bg2,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bg3,
          selectedColor: AppColors.accentDim,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            side: const BorderSide(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
}
