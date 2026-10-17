import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Restricted palette: near-black ground, fog grey, one intrusive accent.
abstract final class SoulwalkerPalette {
  static const Color ground = Color(0xFF0B0A0C);
  static const Color fog = Color(0xFF8A8790);
  static const Color mist = Color(0xFF1A181C);
  static const Color accent = Color(0xFFC4A574);
  static const Color onGround = Color(0xFFE6E2DA);
}

ThemeData buildSoulwalkerTheme() {
  final TextTheme serif = GoogleFonts.cormorantGaramondTextTheme(
    ThemeData.dark().textTheme,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SoulwalkerPalette.ground,
    colorScheme: const ColorScheme.dark(
      surface: SoulwalkerPalette.mist,
      primary: SoulwalkerPalette.accent,
      onPrimary: SoulwalkerPalette.ground,
      onSurface: SoulwalkerPalette.onGround,
      outline: SoulwalkerPalette.fog,
    ),
    textTheme: serif.apply(
      bodyColor: SoulwalkerPalette.onGround,
      displayColor: SoulwalkerPalette.onGround,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SoulwalkerPalette.mist,
      indicatorColor: SoulwalkerPalette.accent.withValues(alpha: 0.2),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(
        (serif.labelMedium ?? const TextStyle()).copyWith(
          color: SoulwalkerPalette.fog,
        ),
      ),
    ),
  );
}
