import 'package:flutter/material.dart';
import 'package:juzreviz/domain/model/enums.dart';

/// Tokens de design « Lanterne » exposés via `ThemeExtension`.
/// Aucune couleur en dur ailleurs dans l'app : tout passe par ces tokens.
@immutable
class LanternTokens extends ThemeExtension<LanternTokens> {
  const LanternTokens({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.border,
    required this.ember,
    required this.fragile,
    required this.fresh,
    required this.fading,
    required this.stale,
    required this.blank,
    required this.scar,
    required this.arabicFamily,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color accent;
  final Color accentSoft;

  /// Texte/icône posé sur un fond [accent] (jamais blanc sur or).
  final Color accentInk;
  final Color ink;
  final Color inkSoft;

  /// Labels de section, hints — plus discret que [inkSoft].
  final Color inkFaint;

  /// Bordures fines (0.5px) par défaut.
  final Color border;
  final Color ember;

  // Couleurs de chaleur (Atlas / Reader).
  final Color fragile;
  final Color fresh;
  final Color fading;
  final Color stale;

  /// Verset vierge — gris éteint, nettement distinct d'un état actif.
  final Color blank;
  final Color scar;

  final String? arabicFamily;

  Color heat(HeatState s) => switch (s) {
        HeatState.fragile => fragile,
        HeatState.fresh => fresh,
        HeatState.fading => fading,
        HeatState.stale => stale,
        HeatState.blank => blank,
      };

  @override
  LanternTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? border,
    Color? ember,
    Color? fragile,
    Color? fresh,
    Color? fading,
    Color? stale,
    Color? blank,
    Color? scar,
    String? arabicFamily,
  }) =>
      LanternTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        accentInk: accentInk ?? this.accentInk,
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        inkFaint: inkFaint ?? this.inkFaint,
        border: border ?? this.border,
        ember: ember ?? this.ember,
        fragile: fragile ?? this.fragile,
        fresh: fresh ?? this.fresh,
        fading: fading ?? this.fading,
        stale: stale ?? this.stale,
        blank: blank ?? this.blank,
        scar: scar ?? this.scar,
        arabicFamily: arabicFamily ?? this.arabicFamily,
      );

  @override
  LanternTokens lerp(ThemeExtension<LanternTokens>? other, double t) {
    if (other is! LanternTokens) return this;
    return LanternTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      fragile: Color.lerp(fragile, other.fragile, t)!,
      fresh: Color.lerp(fresh, other.fresh, t)!,
      fading: Color.lerp(fading, other.fading, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      blank: Color.lerp(blank, other.blank, t)!,
      scar: Color.lerp(scar, other.scar, t)!,
      arabicFamily: t < 0.5 ? arabicFamily : other.arabicFamily,
    );
  }
}

/// Échelle typographique en tokens (tailles fluides ajustées en widget).
class LanternType {
  static const double displayArabic = 34;
  static const double verseArabic = 30;
  static const double gloss = 13;
  static const double uiTitle = 20;
  static const double uiBody = 15;
  static const double caption = 12;
}

/// Specs de motion (durées/easing) en tokens.
class LanternMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 460);
  static const Curve emphasized = Curves.easeOutCubic;
}

class LanternSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 36;
  static const double radius = 18;
}
