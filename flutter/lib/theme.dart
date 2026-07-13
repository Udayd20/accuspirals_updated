import 'package:flutter/material.dart';

/// Brand palette + XP-flavoured surface colours (light & dark).
class Brand {
  static const blue = Color(0xFF2F6FD0);
  static const blueDark = Color(0xFF1A4D97);
  static const brass = Color(0xFFB08D57);
  static const green = Color(0xFF2F8F4E);
  static const amber = Color(0xFFB7791F);
  static const purple = Color(0xFF7C4BD0);
  static const red = Color(0xFFC0392B);
}

/// XP window/chrome colours resolved per brightness.
class Xp {
  final Color titleA, titleB, chrome, chromeLine, paneA, paneB, panel, panelHead,
      border, ink, mutedInk, statusA, statusB, desktop, navSel, navSelInk;
  const Xp({
    required this.titleA, required this.titleB, required this.chrome, required this.chromeLine,
    required this.paneA, required this.paneB, required this.panel, required this.panelHead,
    required this.border, required this.ink, required this.mutedInk,
    required this.statusA, required this.statusB, required this.desktop,
    required this.navSel, required this.navSelInk,
  });

  static const light = Xp(
    titleA: Color(0xFF2F6FD6), titleB: Color(0xFF1A4D97),
    chrome: Color(0xFFEFF2F7), chromeLine: Color(0xFFC3CED9),
    paneA: Color(0xFFE7EFFB), paneB: Color(0xFFD3E1F4),
    panel: Colors.white, panelHead: Color(0xFFEEF3FB),
    border: Color(0xFFC3CED9), ink: Color(0xFF1B2733), mutedInk: Color(0xFF5A6B7B),
    statusA: Color(0xFFF3F6FA), statusB: Color(0xFFE6ECF3), desktop: Color(0xFFDDE6F1),
    navSel: Color(0xFF3B82D6), navSelInk: Colors.white,
  );

  static const dark = Xp(
    titleA: Color(0xFF1A4D97), titleB: Color(0xFF10345F),
    chrome: Color(0xFF141B24), chromeLine: Color(0xFF263140),
    paneA: Color(0xFF141D29), paneB: Color(0xFF0F1720),
    panel: Color(0xFF161F2A), panelHead: Color(0xFF1C2734),
    border: Color(0xFF263140), ink: Color(0xFFC7D2DF), mutedInk: Color(0xFF8EA3B8),
    statusA: Color(0xFF1A232E), statusB: Color(0xFF141B24), desktop: Color(0xFF0B1119),
    navSel: Color(0xFF2A63AD), navSelInk: Colors.white,
  );

  static Xp of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.light)
      .copyWith(secondary: Brand.brass, surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Xp.light.desktop,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      elevation: 0, margin: const EdgeInsets.all(6), color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: Color(0xFFC3CED9)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Colors.white,
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.dark)
      .copyWith(secondary: Brand.brass, surface: const Color(0xFF161F2A));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Xp.dark.desktop,
    fontFamily: 'Segoe UI',
    cardTheme: CardThemeData(
      elevation: 0, margin: const EdgeInsets.all(6), color: const Color(0xFF161F2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: Color(0xFF263140)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFF0F1720),
    ),
  );
}

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  bool get isDark => mode == ThemeMode.dark;
  void toggle() {
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'AVAILABLE': return Brand.green;
    case 'ISSUED': return Brand.amber;
    case 'REGRINDING':
    case 'REPAIR': return Brand.purple;
    case 'SCRAP':
    case 'REJECTED': return Brand.red;
    default: return Colors.grey;
  }
}
