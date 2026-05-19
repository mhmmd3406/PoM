import 'package:flutter/material.dart';

// Design tokens from PoM Part 1 handoff.
// Light theme uses warm cream (never hospital-white). Amber for alerts, not red.
abstract final class AppColors {
  // ── Light surfaces ──────────────────────────────────────────────────────────
  static const lightBg         = Color(0xFFF6F1E8);
  static const lightBgAlt      = Color(0xFFEFE9DE);
  static const lightSurface    = Color(0xFFFFFFFF);
  static const lightSurfaceSoft= Color(0xFFFBF7EF);

  // ── Light text ──────────────────────────────────────────────────────────────
  static const lightInk        = Color(0xFF1B2230);
  static const lightInk2       = Color(0xFF4A5163);
  static const lightInk3       = Color(0xFF7A8092);

  // ── Brand ───────────────────────────────────────────────────────────────────
  static const blue            = Color(0xFF4F7CC4);
  static const blueDeep        = Color(0xFF3B5F9E);
  static const blueSoft        = Color(0xFFE2ECFA);
  static const blueWash        = Color(0xFFF0F4FC);

  static const sage            = Color(0xFF6DAE7E);
  static const sageDeep        = Color(0xFF3F8553);
  static const sageSoft        = Color(0xFFDEEBDD);
  static const sageWash        = Color(0xFFECF4EB);

  static const amber           = Color(0xFFE8A03C);
  static const amberSoft       = Color(0xFFF8E4C0);
  static const amberWash       = Color(0xFFFCF2DD);
  static const amberDeep       = Color(0xFF876018);

  static const rose            = Color(0xFFD67A6A);
  static const roseSoft        = Color(0xFFF4D9D3);

  // Earth tones
  static const clay            = Color(0xFFB17F4A);
  static const moss            = Color(0xFF8AA67A);

  // ── Dark surfaces ───────────────────────────────────────────────────────────
  static const darkBg          = Color(0xFF0E1320);
  static const darkBgAlt       = Color(0xFF141A29);
  static const darkSurface     = Color(0xFF1B2233);
  static const darkSurfaceSoft = Color(0xFF222B3F);

  // ── Dark text ───────────────────────────────────────────────────────────────
  static const darkInk         = Color(0xFFF1ECDF);
  static const darkInk2        = Color(0xFFC9C5B8);
  static const darkInk3        = Color(0xFF8A8E9D);

  // ── Dark brand ──────────────────────────────────────────────────────────────
  static const blueDark        = Color(0xFF7BAEEE);
  static const blueDeepDark    = Color(0xFF5A8FD6);
  static const blueSoftDark    = Color(0xFF2A3A57);
  static const blueWashDark    = Color(0xFF1F2840);

  static const sageDark        = Color(0xFF87C99A);
  static const sageDeepDark    = Color(0xFF62A578);
  static const sageSoftDark    = Color(0xFF2A4036);
  static const sageWashDark    = Color(0xFF1F3128);

  static const amberDark       = Color(0xFFF2B964);
  static const amberSoftDark   = Color(0xFF4A3C20);

  // LinkedIn brand
  static const linkedIn        = Color(0xFF0A66C2);

  // Borders
  static const borderLight     = Color(0x14000000);
  static const borderDark      = Color(0x14F1ECDF);
  static const dividerLight    = Color(0x0A000000);
  static const dividerDark     = Color(0x0AF1ECDF);
}
