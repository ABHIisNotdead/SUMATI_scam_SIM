import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Design Tokens
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color deepTeal = Color(0xFF004D40);
  static const Color amber = Color(0xFFF2A900);
  static const Color red = Color(0xFFB71C1C);
  static const Color green = Color(0xFF1B7A3D);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardWhite = Color(0xFFFFFFFF);

  static ThemeData get light {
    final baseTextTheme = GoogleFonts.atkinsonHyperlegibleTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: amber,
        error: red,
        surface: cardWhite,
      ).copyWith(surface: background),
      scaffoldBackgroundColor: background,
      textTheme: baseTextTheme.copyWith(
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 14),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 18),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 20),
        titleSmall: baseTextTheme.titleSmall?.copyWith(fontSize: 16),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 20),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontSize: 30, fontWeight: FontWeight.bold),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60), // Phase 1 non-negotiable
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.atkinsonHyperlegibleTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryTeal,
        primary: const Color(0xFF4DB6AC),
        secondary: amber,
        error: const Color(0xFFEF9A9A),
        surface: const Color(0xFF1E1E1E),
      ).copyWith(surface: const Color(0xFF121212)),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: baseTextTheme.copyWith(
        bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 14),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 18),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 20),
        titleSmall: baseTextTheme.titleSmall?.copyWith(fontSize: 16),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 20),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF004D40),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: const Color(0xFF4DB6AC),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme => dark;
}
