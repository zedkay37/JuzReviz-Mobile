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

// Palette de chaleur SRS — harmonisée, identique sur les thèmes sombres.
const _heatFresh = Color(0xFF3B6D11);
const _heatFading = Color(0xFFBA7517);
const _heatFragile = Color(0xFFA32D2D);
const _heatStale = Color(0xFF854F0B);
const _heatBlank = Color(0xFF3A3A3A);

// Thème de référence « Noir & Or » : fond noir, accent or ponctuel, texte crème.
const _lanterneTokens = LanternTokens(
  background: Color(0xFF000000),
  surface: Color(0xFF0E0E0E),
  surfaceHigh: Color(0xFF161410),
  accent: Color(0xFFD4A437),
  accentSoft: Color(0xFF7A5E33),
  accentInk: Color(0xFF000000),
  ink: Color(0xFFECE6D8),
  inkSoft: Color(0xFF6A6558),
  inkFaint: Color(0xFF4A463D),
  border: Color(0xFF1F1F1F),
  ember: Color(0xFFBA7517),
  fragile: _heatFragile,
  fresh: _heatFresh,
  fading: _heatFading,
  stale: _heatStale,
  blank: _heatBlank,
  scar: Color(0xFFBA7517),
  arabicFamily: 'AmiriQuran',
);

// Rawda — re-dérivé : surfaces noires teintées vert très sombre, même or.
const _rawdaTokens = LanternTokens(
  background: Color(0xFF030806),
  surface: Color(0xFF0B130E),
  surfaceHigh: Color(0xFF141C16),
  accent: Color(0xFFD4A437),
  accentSoft: Color(0xFF5E5230),
  accentInk: Color(0xFF000000),
  ink: Color(0xFFE9EFE6),
  inkSoft: Color(0xFF6B756A),
  inkFaint: Color(0xFF49524A),
  border: Color(0xFF1A211C),
  ember: Color(0xFFBA7517),
  fragile: _heatFragile,
  fresh: _heatFresh,
  fading: _heatFading,
  stale: _heatStale,
  blank: _heatBlank,
  scar: Color(0xFFBA7517),
  arabicFamily: 'AmiriQuran',
);

// Parchemin — clair : crème, encre brune, or foncé. accentInk crème sur or sombre.
const _parcheminTokens = LanternTokens(
  background: Color(0xFFF3E9D2),
  surface: Color(0xFFEADFC4),
  surfaceHigh: Color(0xFFE0D2B0),
  accent: Color(0xFF8A5B1C),
  accentSoft: Color(0xFFCBB17E),
  accentInk: Color(0xFFF8F1E0),
  ink: Color(0xFF2C2113),
  inkSoft: Color(0xFF6E5C42),
  inkFaint: Color(0xFF9A8862),
  border: Color(0xFFD8C7A0),
  ember: Color(0xFFB5662A),
  fragile: Color(0xFF9A2C2C),
  fresh: Color(0xFF3B6D11),
  fading: Color(0xFFA9802F),
  stale: Color(0xFF7C5E37),
  blank: Color(0xFFC9BFA8),
  scar: Color(0xFFB5662A),
  arabicFamily: 'AmiriQuran',
);

// Contraste élevé — noir pur, or vif, encre blanche.
const _highContrastTokens = LanternTokens(
  background: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  surfaceHigh: Color(0xFF1A1A1A),
  accent: Color(0xFFFFC430),
  accentSoft: Color(0xFF8A6A1E),
  accentInk: Color(0xFF000000),
  ink: Color(0xFFFFFFFF),
  inkSoft: Color(0xFFCFCFCF),
  inkFaint: Color(0xFF8A8A8A),
  border: Color(0xFF2A2A2A),
  ember: Color(0xFFFF9E40),
  fragile: Color(0xFFFF6B57),
  fresh: Color(0xFF6EE7A0),
  fading: Color(0xFFFFD15A),
  stale: Color(0xFFB89A6A),
  blank: Color(0xFF4A4A4A),
  scar: Color(0xFFFF9E40),
  arabicFamily: 'AmiriQuran',
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
    onPrimary: tokens.accentInk,
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
    dividerColor: tokens.border,
  );
}

/// Accès rapide aux tokens depuis un `BuildContext`.
extension LanternContext on BuildContext {
  LanternTokens get lantern =>
      Theme.of(this).extension<LanternTokens>() ?? _lanterneTokens;
}
