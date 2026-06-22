import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

/// Rendu arabe : RTL, **jamais de coupure intra-mot ni de harakat**.
/// Compose en `Text.rich` avec retour à la ligne au niveau du mot.
class ArabicText extends StatelessWidget {
  const ArabicText(
    this.text, {
    super.key,
    this.fontSize = 30,
    this.color,
    this.height = 1.9,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final Color? color;
  final double height;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final tokens = context.lantern;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: textAlign,
        // Le retour à la ligne se fait au niveau du mot (espaces) ; les
        // diacritiques restent collés à leur lettre car jamais d'espace inséré.
        softWrap: true,
        style: TextStyle(
          fontFamily: tokens.arabicFamily,
          fontSize: fontSize,
          height: height,
          color: color ?? tokens.ink,
          fontFeatures: const [FontFeature.enable('calt')],
        ),
      ),
    );
  }
}
