import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/features/playlists/playlists_screen.dart';

Widget _app() => ProviderScope(
  overrides: [jsonStoreProvider.overrideWithValue(MemoryJsonStore())],
  child: const MaterialApp(home: PlaylistsScreen()),
);

void main() {
  testWidgets('créer une playlist puis Annuler ne crashe pas', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nouvelle playlist'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Crée une playlist pour regrouper tes passages de lecture ou de révision.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('créer une playlist via OK l’ajoute à la liste', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hifz du matin');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hifz du matin'), findsOneWidget);
  });

  testWidgets('le nom vide ne ferme pas le dialogue', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    var ok = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'OK'),
    );
    expect(ok.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    ok = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK'));
    expect(ok.onPressed, isNull);
    expect(find.text('Saisis un nom.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Révision du soir');
    await tester.pump();
    ok = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK'));
    expect(ok.onPressed, isNotNull);
  });

  testWidgets('supprimer une playlist exige une confirmation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'À conserver');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('À conserver'), findsOneWidget);
    final menu = find.byWidgetPredicate((widget) => widget is PopupMenuButton);
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer « À conserver » ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('À conserver'), findsOneWidget);
  });
}
