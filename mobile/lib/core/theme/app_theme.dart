import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _buildTextTheme(Color ink, Color ink2, Color ink3) {
    final display = GoogleFonts.bricolageGrotesque();
    final body = GoogleFonts.plusJakartaSans();
    return TextTheme(
      displayLarge:  display.copyWith(fontSize: 57, fontWeight: FontWeight.w600, color: ink, letterSpacing: -1.5),
      displayMedium: display.copyWith(fontSize: 45, fontWeight: FontWeight.w600, color: ink, letterSpacing: -1.0),
      displaySmall:  display.copyWith(fontSize: 36, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.8),
      headlineLarge: display.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.5),
      headlineMedium:display.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.5),
      headlineSmall: display.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.3),
      titleLarge:    body.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      titleMedium:   body.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
      titleSmall:    body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      bodyLarge:     body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: ink),
      bodyMedium:    body.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: ink2),
      bodySmall:     body.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: ink3),
      labelLarge:    body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      labelMedium:   body.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: ink2),
      labelSmall:    body.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: ink3, letterSpacing: 0.5),
    );
  }

  static ThemeData get light {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:          AppColors.blue,
      onPrimary:        Colors.white,
      primaryContainer: AppColors.blueSoft,
      onPrimaryContainer: AppColors.blueDeep,
      secondary:        AppColors.sage,
      onSecondary:      Colors.white,
      secondaryContainer: AppColors.sageSoft,
      onSecondaryContainer: AppColors.sageDeep,
      tertiary:         AppColors.amber,
      onTertiary:       Colors.white,
      tertiaryContainer: AppColors.amberWash,
      onTertiaryContainer: AppColors.amberDeep,
      error:            AppColors.rose,
      onError:          Colors.white,
      errorContainer:   AppColors.roseSoft,
      onErrorContainer: Color(0xFF8B2A1A),
      surface:          AppColors.lightSurface,
      onSurface:        AppColors.lightInk,
      surfaceContainerHighest: AppColors.lightBgAlt,
      onSurfaceVariant: AppColors.lightInk2,
      outline:          AppColors.borderLight,
      outlineVariant:   AppColors.dividerLight,
      shadow:           Color(0x1A000000),
      scrim:            Color(0x33000000),
      inverseSurface:   AppColors.darkSurface,
      onInverseSurface: AppColors.darkInk,
      inversePrimary:   AppColors.blueDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBg,
      textTheme: _buildTextTheme(AppColors.lightInk, AppColors.lightInk2, AppColors.lightInk3),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.lightInk,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightInk,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.borderLight),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.lightSurfaceSoft,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.blueSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.blue, size: 24);
          }
          return const IconThemeData(color: AppColors.lightInk3, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.blue);
          }
          return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.lightInk3);
        }),
        height: 68,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.dividerLight, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.lightInk,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.darkInk, fontSize: 14),
      ),
    );
  }

  static ThemeData get dark {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary:          AppColors.blueDark,
      onPrimary:        AppColors.darkBg,
      primaryContainer: AppColors.blueSoftDark,
      onPrimaryContainer: AppColors.blueDark,
      secondary:        AppColors.sageDark,
      onSecondary:      AppColors.darkBg,
      secondaryContainer: AppColors.sageSoftDark,
      onSecondaryContainer: AppColors.sageDark,
      tertiary:         AppColors.amberDark,
      onTertiary:       AppColors.darkBg,
      tertiaryContainer: AppColors.amberSoftDark,
      onTertiaryContainer: AppColors.amberDark,
      error:            AppColors.rose,
      onError:          Colors.white,
      errorContainer:   Color(0xFF4A1A14),
      onErrorContainer: AppColors.rose,
      surface:          AppColors.darkSurface,
      onSurface:        AppColors.darkInk,
      surfaceContainerHighest: AppColors.darkSurfaceSoft,
      onSurfaceVariant: AppColors.darkInk2,
      outline:          AppColors.borderDark,
      outlineVariant:   AppColors.dividerDark,
      shadow:           Color(0x33000000),
      scrim:            Color(0x66000000),
      inverseSurface:   AppColors.lightSurface,
      onInverseSurface: AppColors.lightInk,
      inversePrimary:   AppColors.blue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBg,
      textTheme: _buildTextTheme(AppColors.darkInk, AppColors.darkInk2, AppColors.darkInk3),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.darkInk,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blueDark,
          foregroundColor: AppColors.darkBg,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkInk,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.borderDark),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blueDark,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.blueDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.darkSurfaceSoft,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkInk),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.blueSoftDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.blueDark, size: 24);
          }
          return const IconThemeData(color: AppColors.darkInk3, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.blueDark);
          }
          return GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.darkInk3);
        }),
        height: 68,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.dividerDark, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.darkSurfaceSoft,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.darkInk, fontSize: 14),
      ),
    );
  }
}
