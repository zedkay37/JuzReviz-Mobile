import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

enum AppTheme { lanterne, rawda, parchemin, highContrast }

AppTheme appThemeFromString(String s) => switch (s) {
      'rawda' => AppTheme.rawda,
      'parchemin' => AppTheme.parchemin,
      'highContrast' => AppTheme.highContrast,
      _ => AppTheme.lanterne,
    };

extension AppThemeId on AppTheme {
  String get id => switch (this) {
        AppTheme.lanterne => 'lanterne',
        AppTheme.rawda => 'rawda',
        AppTheme.parchemin => 'parchemin',
        AppTheme.highContrast => 'highContrast',
      };

  String get label => switch (this) {
        AppTheme.lanterne => 'Lanterne (nuit)',
        AppTheme.rawda => 'Rawda (jardin)',
        AppTheme.parchemin => 'Parchemin',
        AppTheme.highContrast => 'Contraste élevé',
      };

  bool get isDark => this != AppTheme.parchemin;
}

const _lanterneTokens = LanternTokens(
  background: Color(0xFF0B0B0D),
  surface: Color(0xFF141318),
  surfaceHigh: Color(0xFF1E1C22),
  accent: Color(0xFFE8B765),
  accentSoft: Color(0xFF7A5E33),
  ink: Color(0xFFF4ECDD),
  inkSoft: Color(0xFFB7AE9E),
  ember: Color(0xFFE8853F),
  fragile: Color(0xFFD66A4B),
  fresh: Color(0xFF6FA67B),
  fading: Color(0xFFC9A05A),
  stale: Color(0xFF8A6E4E),
  scar: Color(0xFFE8853F),
  arabicFamily: null,
);

const _rawdaTokens = LanternTokens(
  background: Color(0xFF0C1410),
  surface: Color(0xFF132019),
  surfaceHigh: Color(0xFF1B2A21),
  accent: Color(0xFFD8B45A),
  accentSoft: Color(0xFF5E5230),
  ink: Color(0xFFEAF1E6),
  inkSoft: Color(0xFFA9BBA7),
  ember: Color(0xFFDDA94B),
  fragile: Color(0xFFCB6A4F),
  fresh: Color(0xFF7BB489),
  fading: Color(0xFFC9A858),
  stale: Color(0xFF7E7048),
  scar: Color(0xFFDDA94B),
  arabicFamily: null,
);

const _parcheminTokens = LanternTokens(
  background: Color(0xFFF3E9D2),
  surface: Color(0xFFEADFC4),
  surfaceHigh: Color(0xFFE0D2B0),
  accent: Color(0xFF9A6B26),
  accentSoft: Color(0xFFCBB17E),
  ink: Color(0xFF3A2E1C),
  inkSoft: Color(0xFF6E5C42),
  ember: Color(0xFFB5662A),
  fragile: Color(0xFFB24B33),
  fresh: Color(0xFF4E7C53),
  fading: Color(0xFFA9802F),
  stale: Color(0xFF7C5E37),
  scar: Color(0xFFB5662A),
  arabicFamily: null,
);

const _highContrastTokens = LanternTokens(
  background: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  surfaceHigh: Color(0xFF161616),
  accent: Color(0xFFFFC857),
  accentSoft: Color(0xFF8A6A1E),
  ink: Color(0xFFFFFFFF),
  inkSoft: Color(0xFFCFCFCF),
  ember: Color(0xFFFF9E40),
  fragile: Color(0xFFFF6B57),
  fresh: Color(0xFF6EE7A0),
  fading: Color(0xFFFFD15A),
  stale: Color(0xFFB89A6A),
  scar: Color(0xFFFF9E40),
  arabicFamily: null,
);

LanternTokens tokensFor(AppTheme theme) => switch (theme) {
      AppTheme.lanterne => _lanterneTokens,
      AppTheme.rawda => _rawdaTokens,
      AppTheme.parchemin => _parcheminTokens,
      AppTheme.highContrast => _highContrastTokens,
    };

ThemeData buildTheme(AppTheme theme, {Color? dynamicAccent}) {
  var tokens = tokensFor(theme);
  if (dynamicAccent != null && theme.isDark) {
    // Dynamic color bridé sur la rampe sombre : on ne change que l'accent.
    tokens = tokens.copyWith(accent: dynamicAccent);
  }
  final brightness = theme.isDark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.accent,
    brightness: brightness,
  ).copyWith(
    surface: tokens.surface,
    primary: tokens.accent,
    onPrimary: tokens.background,
    onSurface: tokens.ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.background,
    colorScheme: scheme,
    extensions: [tokens],
    textTheme: (brightness == Brightness.dark
            ? Typography.material2021().white
            : Typography.material2021().black)
        .apply(bodyColor: tokens.ink, displayColor: tokens.ink),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.background,
      foregroundColor: tokens.ink,
      elevation: 0,
      centerTitle: false,
    ),
    iconTheme: IconThemeData(color: tokens.inkSoft),
    dividerColor: tokens.surfaceHigh,
  );
}

/// Accès rapide aux tokens depuis un `BuildContext`.
extension LanternContext on BuildContext {
  LanternTokens get lantern =>
      Theme.of(this).extension<LanternTokens>() ?? _lanterneTokens;
}
