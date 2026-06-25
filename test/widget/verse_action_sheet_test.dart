import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/verse_action_sheet.dart';
import 'package:juzreviz/data/common/json_store.dart';

Widget _app(Widget child) => ProviderScope(
  overrides: [jsonStoreProvider.overrideWithValue(MemoryJsonStore())],
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('le menu verset scrolle sans overflow sur petit écran', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 360,
          height: 420,
          child: VerseActionSheet(
            verseKey: '3:1',
            arabicPreview:
                'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
            reference: 'Aal-i-Imraan +1',
            showDisplay: true,
            onSelectRange: () {},
            onPlaySingle: () {},
            onPlayFrom: () {},
            onRepeat: () {},
            onStop: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Marquer fragile'), findsOneWidget);
    expect(find.text('Répéter ce passage'), findsOneWidget);
  });
}
