import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light(FlexScheme scheme) {
    return FlexThemeData.light(
      scheme: scheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.lato().fontFamily,
    );
  }

  static ThemeData dark(FlexScheme scheme) {
    return FlexThemeData.dark(
      scheme: scheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.lato().fontFamily,
    );
  }
}
