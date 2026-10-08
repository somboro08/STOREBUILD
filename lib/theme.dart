import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette de l'app : change les valeurs ici pour changer les couleurs partout (clair et sombre).
class C {
  static bool light = false; // piloté par AppState.setThemeMode

  static Color _p(int dark, int lightV) => Color(light ? lightV : dark);

  static Color get bg => _p(0xFF0B141A, 0xFFFFFFFF);
  static Color get bubble => _p(0xFF1F2C34, 0xFFF0F2F5);
  static Color get chip => _p(0xFF202C33, 0xFFE9EDEF);
  static Color get green => _p(0xFF25D366, 0xFF1BA05A);
  static Color get greenPill => _p(0xFF0F3B2E, 0xFFD9FDD3);
  static Color get text => _p(0xFFE9EDEF, 0xFF111B21);
  static Color get sub => _p(0xFF8696A0, 0xFF667781);
  static Color get link => _p(0xFF53BDEB, 0xFF027EB5);
  static Color get divider => _p(0xFF111B21, 0xFFF0F2F5);
  static Color get menu => _p(0xFF111B21, 0xFFFFFFFF);
  static Color get quote => _p(0xFF16222A, 0xFFE7ECEF);
  static Color get border => _p(0xFF2A3942, 0xFFD1D7DB);
}

ThemeData? _cache;
bool? _cacheLight;

ThemeData appTheme() {
  if (_cache != null && _cacheLight == C.light) return _cache!;
  final base = C.light ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
  _cacheLight = C.light;
  return _cache = base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: base.colorScheme.copyWith(primary: C.green, surface: C.bg),
    textTheme: GoogleFonts.robotoTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.menu,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.roboto(fontSize: 16, color: C.text),
    ),
    dividerColor: C.divider,
  );
}

/// Force la reconstruction de tout l'arbre (utile après un changement de thème).
void rebuildApp() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
