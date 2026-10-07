import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFF0B141A);
  static const bubble = Color(0xFF1F2C34);
  static const chip = Color(0xFF202C33);
  static const green = Color(0xFF25D366);
  static const greenPill = Color(0xFF0F3B2E);
  static const text = Color(0xFFE9EDEF);
  static const sub = Color(0xFF8696A0);
  static const link = Color(0xFF53BDEB);
  static const divider = Color(0xFF111B21);
}

ThemeData appTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(primary: C.green, surface: C.bg),
    textTheme: GoogleFonts.robotoTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF111B21),
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.roboto(fontSize: 16, color: C.text),
    ),
    dividerColor: C.divider,
  );
}
