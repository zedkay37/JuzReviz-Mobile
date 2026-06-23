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

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle playlist'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Aucune playlist. Compose tes passages favoris.'),
        findsOneWidget);
  });

  testWidgets('créer une playlist via OK l’ajoute à la liste', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hifz du matin');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hifz du matin'), findsOneWidget);
  });
}
