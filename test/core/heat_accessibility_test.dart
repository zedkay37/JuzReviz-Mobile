import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/core/designsystem/components/heat_widgets.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/enums.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('HeatCell garde un contraste WCAG AA dans tous les thèmes', () {
    for (final theme in AppTheme.values) {
      final tokens = tokensFor(theme);
      for (final state in HeatState.values) {
        final expectedBackground = state == HeatState.blank
            ? tokens.blank
            : Color.alphaBlend(
                tokens
                    .heat(state)
                    .withValues(alpha: LanternTokens.heatCellOpacity),
                tokens.background,
              );
        final background = tokens.heatCellBackground(state);
        final foreground = tokens.heatCellForeground(state);
        final ratio = _contrastRatio(foreground, background);

        expect(
          background,
          expectedBackground,
          reason: '${theme.name}/${state.name} doit utiliser le fond rendu',
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${theme.name}/${state.name} contraste ${ratio.toStringAsFixed(2)}',
        );
      }
    }
  });

  testWidgets('HeatCell expose état, cicatrice et actions aux lecteurs écran', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(AppTheme.lanterne),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: HeatCell(
                ayah: 12,
                state: HeatState.fragile,
                scarred: true,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Verset 12')),
      isSemantics(
        label: 'Verset 12',
        value: 'Fragile, cicatrice',
        hint: 'Appui long pour ouvrir les actions',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    semantics.dispose();
  });
}
