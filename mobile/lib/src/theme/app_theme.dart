import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF111827);
  static const mutedInk = Color(0xFF6F7890);
  static const night = Color(0xFF0B0F1F);
  static const nightSoft = Color(0xFF111827);
  static const panel = Color(0xFF0F1629);
  static const panelRaised = Color(0xFF151D33);
  static const stroke = Color(0xFF29324D);
  static const shell = Color(0xFFF7F4F0);
  static const surface = Color(0xFFFFFFFF);
  static const rose = Color(0xFFFF2D9A);
  static const teal = Color(0xFF00A6A6);
  static const cyan = Color(0xFF65E4FF);
  static const amber = Color(0xFFFFB703);
  static const indigo = Color(0xFF4C6FFF);
  static const violet = Color(0xFF8B5CF6);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: rose,
      brightness: Brightness.light,
      primary: rose,
      secondary: teal,
      tertiary: amber,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: night,
      fontFamily: 'System',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.35, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: ink),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF11182A).withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: cyan,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.34),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: cyan,
        suffixIconColor: Colors.white70,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cyan.withValues(alpha: 0.72),
            width: 1.25,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: rose.withValues(alpha: 0.78)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rose, width: 1.25),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0B1020),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: violet.withValues(alpha: 0.28)),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: rose.withValues(alpha: 0.28),
          disabledForegroundColor: Colors.white54,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: violet.withValues(alpha: 0.42)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFFFDF9FF),
        indicatorColor: rose.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? rose : mutedInk,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? rose : mutedInk,
          ),
        ),
      ),
    );
  }
}
