import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AtelierColors {
  static const ink = Color(0xFF12100E);
  static const panel = Color(0xFF1C1814);
  static const raise = Color(0xFF2A241E);
  static const rice = Color(0xFFF4ECDF);
  static const mist = Color(0xFFA89880);
  static const cinnabar = Color(0xFFC44536);
  static const line = Color(0xFF3D342C);
}

Color fade(Color color, double alpha) => color.withValues(alpha: alpha.clamp(0.0, 1.0));

ThemeData buildAtelierTheme() {
  final display = GoogleFonts.cormorantGaramond(color: AtelierColors.rice);
  final body = GoogleFonts.outfit(color: AtelierColors.rice);
  final text = TextTheme(
    displayLarge: display.copyWith(fontSize: 48, height: 1, fontWeight: FontWeight.w500),
    displayMedium: display.copyWith(fontSize: 32, height: 1.05, fontWeight: FontWeight.w500),
    headlineMedium: display.copyWith(fontSize: 26, height: 1.1),
    titleLarge: display.copyWith(fontSize: 22, height: 1.15),
    titleMedium: body.copyWith(fontSize: 16, height: 1.3),
    bodyMedium: body.copyWith(fontSize: 15, height: 1.45, color: AtelierColors.mist),
    bodySmall: body.copyWith(fontSize: 12, height: 1.35, color: AtelierColors.mist),
    labelLarge: body.copyWith(fontSize: 14, height: 1.2, color: AtelierColors.rice),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AtelierColors.ink,
    canvasColor: AtelierColors.ink,
    colorScheme: const ColorScheme.dark(
      surface: AtelierColors.panel,
      primary: AtelierColors.cinnabar,
      onPrimary: AtelierColors.rice,
      onSurface: AtelierColors.rice,
      outline: AtelierColors.line,
    ),
    textTheme: text,
    splashFactory: InkRipple.splashFactory,
    sliderTheme: const SliderThemeData(
      activeTrackColor: AtelierColors.cinnabar,
      thumbColor: AtelierColors.cinnabar,
      inactiveTrackColor: AtelierColors.line,
      overlayColor: Color(0x33C44536),
    ),
  );
}
