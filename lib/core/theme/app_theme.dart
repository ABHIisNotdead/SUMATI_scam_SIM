import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Design Tokens from Stitch DESIGN.md
  static const Color primary = Color(0xFF005344);
  static const Color primaryContainer = Color(0xFF006D5B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF96EBD5);
  static const Color primaryFixed = Color(0xFF9DF3DC);
  static const Color primaryFixedDim = Color(0xFF81D6C0);

  static const Color secondary = Color(0xFF7E5700);
  static const Color secondaryContainer = Color(0xFFFEB726);
  static const Color onSecondaryContainer = Color(0xFF6C4A00);
  static const Color secondaryFixed = Color(0xFFFFDEAC);
  static const Color secondaryFixedDim = Color(0xFFFFBA36);

  static const Color tertiary = Color(0xFF960014);
  static const Color tertiaryContainer = Color(0xFFBA2027);
  static const Color tertiaryFixed = Color(0xFFFFDAD7);
  static const Color onTertiary = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFFF8FAF7);
  static const Color surfaceContainer = Color(0xFFEDEEEC);
  static const Color surfaceContainerLow = Color(0xFFF2F4F2);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFE7E9E6);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E1);

  static const Color onSurface = Color(0xFF191C1B);
  static const Color onSurfaceVariant = Color(0xFF3E4945);
  static const Color inverseSurface = Color(0xFF2E3130);
  static const Color inverseOnSurface = Color(0xFFF0F1EF);
  static const Color outline = Color(0xFF6E7975);
  static const Color outlineVariant = Color(0xFFBEC9C4);

  // Backward compatibility aliases
  static const Color primaryTeal = primaryContainer;
  static const Color deepTeal = primary;
  static const Color amber = secondaryContainer;
  static const Color red = tertiary;
  static const Color green = primaryContainer;
  static const Color background = surface;
  static const Color cardWhite = surfaceContainerLowest;

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryContainer,
        primary: primaryContainer,
        secondary: secondaryContainer,
        error: tertiary,
        surface: surface,
      ).copyWith(
        surface: surface,
        onSurface: onSurface,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.3,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
          height: 1.35,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w500,
          color: onSurface,
          height: 1.45,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
          height: 1.45,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: surfaceContainerLowest,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE7E9E6), width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 50),
          backgroundColor: primaryContainer,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get dark => light; // Designed as high-contrast accessible light system
  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme => dark;
}
