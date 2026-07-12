import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/features/reader/reader_layout_sheet.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildTheme(AppTheme.lanterne),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void _expectMinimumTapTarget(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}

void main() {
  testWidgets('ChoiceRow expose sélection, activation et cible de 48 dp', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        ChoiceRow<String>(
          title: 'Choix',
          value: 'a',
          options: const [('a', 'Option A'), ('b', 'Option B')],
          onChanged: (_) {},
        ),
      ),
    );

    final selected = find.bySemanticsLabel('Option A');
    expect(
      tester.getSemantics(selected),
      isSemantics(
        label: 'Option A',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _expectMinimumTapTarget(tester, selected);
    semantics.dispose();
  });

  testWidgets('ChoiceRow désactivé annonce son état et ne peut pas être tapé', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        ChoiceRow<String>(
          title: 'Choix désactivé',
          value: 'a',
          options: const [('a', 'Indisponible')],
          enabled: false,
          onChanged: (_) {},
        ),
      ),
    );

    final disabled = find.bySemanticsLabel('Indisponible');
    expect(
      tester.getSemantics(disabled),
      isSemantics(
        label: 'Indisponible',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: false,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: false,
      ),
    );
    _expectMinimumTapTarget(tester, disabled);
    semantics.dispose();
  });

  testWidgets('ChoiceCard et ThemeSwatch exposent leur état sélectionné', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        Column(
          children: [
            ChoiceCard(
              title: 'Sérénité',
              description: 'Sans pression',
              selected: true,
              onTap: () {},
            ),
            ThemeSwatch(
              theme: AppTheme.highContrast,
              selected: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    final card = find.bySemanticsLabel('Sérénité');
    expect(
      tester.getSemantics(card),
      isSemantics(
        label: 'Sérénité',
        value: 'Sans pression',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _expectMinimumTapTarget(tester, card);

    final theme = find.bySemanticsLabel('Contraste élevé');
    expect(
      tester.getSemantics(theme),
      isSemantics(
        label: 'Contraste élevé',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _expectMinimumTapTarget(tester, theme);
    semantics.dispose();
  });

  testWidgets('les cartes de disposition exposent rôle, sélection et cible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = MemoryJsonStore();

    await tester.pumpWidget(
      _app(
        const ReaderLayoutSheet(),
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          mushafAvailableProvider.overrideWith((_) async => false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final flexible = find.bySemanticsLabel('Flexible');
    expect(
      tester.getSemantics(flexible),
      isSemantics(
        label: 'Flexible',
        value: 'Taille de police personnalisable et mise en page flexible',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _expectMinimumTapTarget(tester, flexible);
    semantics.dispose();
  });
}
