import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — kept 1:1 with kadd-mockups.html so the built app
/// matches the approved mockups exactly.
class AppColors {
  static const ink = Color(0xFF12151B);
  static const surface = Color(0xFF1B2029);
  static const surface2 = Color(0xFF232935);
  static const line = Color(0xFF2A303C);
  static const signal = Color(0xFFFF4B2B); // effort / lock accent
  static const signalDim = Color(0xFF7A2F22);
  static const unlock = Color(0xFFD4FF3D); // progress / verified accent
  static const text = Color(0xFFEDEEF0);
  static const textDim = Color(0xFF8B92A0);
  static const textFaint = Color(0xFF5B6270);
}

class AppTextStyles {
  static TextStyle kufi({double size = 16, FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.notoKufiArabic(fontSize: size, fontWeight: weight, color: color ?? AppColors.text);

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color ?? AppColors.text);
}

ThemeData buildKaddTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: base.colorScheme.copyWith(
      surface: AppColors.surface,
      primary: AppColors.signal,
      secondary: AppColors.unlock,
    ),
    textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
