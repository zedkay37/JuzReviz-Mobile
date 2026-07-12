import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/features/tafsir/tafsir_panel.dart';

void main() {
  testWidgets('le tafsir conserve le thème Contraste élevé', (tester) async {
    final store = MemoryJsonStore();
    await store.write(
      'settings',
      const Settings(theme: 'highContrast').toJson(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: buildTheme(AppTheme.highContrast),
          home: const Scaffold(body: TafsirPanel(verseKey: '1:1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('tafsir-panel-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, tokensFor(AppTheme.highContrast).background);
  });
}
