import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme() => _buildTheme(Brightness.light);
  static ThemeData darkTheme() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    const bg = AppColors.background;
    const surf = AppColors.surface;
    const onBg = AppColors.onBackground;

    final fredoka = GoogleFonts.fredokaTextTheme(
      TextTheme(
        displayLarge: GoogleFonts.fredoka(fontSize: 32, fontWeight: FontWeight.bold, color: onBg),
        titleLarge: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w600, color: onBg),
        titleMedium: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600, color: onBg),
        bodyLarge: GoogleFonts.fredoka(fontSize: 16, color: onBg),
        bodyMedium: GoogleFonts.fredoka(fontSize: 14, color: onBg),
      ),
    );
    // Fredoka pour le style Kalan + Noto Sans pour emojis / caractères locaux (Mooré, etc.)
    final textTheme = GoogleFonts.notoSansTextTheme(fredoka);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: GoogleFonts.fredoka().fontFamily,
      fontFamilyFallback: [
        GoogleFonts.notoSans().fontFamily ?? 'Noto Sans',
        'Segoe UI Emoji',
        'Apple Color Emoji',
        'sans-serif',
      ],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: Colors.black,
        error: AppColors.error,
        onError: Colors.white,
        surface: surf,
        onSurface: onBg,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      // Fond légèrement grisé pour que le ripple Material reste visible (M3 n'expose plus splashColor ici).
      listTileTheme: ListTileThemeData(
        tileColor: const Color(0xFFF5F5F0),
        selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
        iconColor: AppColors.primary,
        textColor: onBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: textTheme,
    );
  }
}
