import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/core/arabic/tajweed.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('les petits textes gardent un contraste AA sur toutes les surfaces', () {
    for (final theme in AppTheme.values) {
      final tokens = tokensFor(theme);
      for (final background in [tokens.surface, tokens.surfaceHigh]) {
        for (final foreground in [
          tokens.ink,
          tokens.inkSoft,
          tokens.inkFaint,
          tokens.accent,
        ]) {
          final ratio = _contrastRatio(foreground, background);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${theme.name}: ${foreground.toARGB32().toRadixString(16)} '
                'sur ${background.toARGB32().toRadixString(16)} = '
                '${ratio.toStringAsFixed(2)}',
          );
        }
      }
    }
  });

  test('les palettes tajwid restent lisibles sur fond sombre et parchemin', () {
    for (final theme in AppTheme.values.where((theme) => theme.isDark)) {
      final background = tokensFor(theme).surfaceHigh;
      for (final color in tajweedColorsDark.values) {
        expect(_contrastRatio(color, background), greaterThanOrEqualTo(3));
      }
    }
    final parchment = tokensFor(AppTheme.parchemin).surfaceHigh;
    for (final color in tajweedColorsLight.values) {
      expect(_contrastRatio(color, parchment), greaterThanOrEqualTo(3));
    }
  });
}
