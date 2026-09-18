import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0E7C61);
  static const Color secondaryColor = Color(0xFF14A37F);
  static const Color accentColor = Color(0xFFE5A93C);
  static const Color darkBackground = Color(0xFF121816);
  static const Color darkSurface = Color(0xFF1B2421);
  static const Color lightBackground = Color(0xFFF7FAF8);
  static const Color lightSurface = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightSurface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: lightSurface,
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.black87;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: lightSurface,
        hourMinuteColor: lightBackground,
        hourMinuteTextColor: Colors.black87,
        dayPeriodColor: primaryColor.withValues(alpha: 0.15),
        dayPeriodTextColor: primaryColor,
        dialBackgroundColor: lightBackground,
        dialHandColor: primaryColor,
        dialTextColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: darkSurface,
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white70;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return null;
        }),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: darkSurface,
        hourMinuteColor: darkBackground,
        hourMinuteTextColor: Colors.white,
        dayPeriodColor: primaryColor.withValues(alpha: 0.3),
        dayPeriodTextColor: Colors.white,
        dialBackgroundColor: darkBackground,
        dialHandColor: primaryColor,
        dialTextColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
