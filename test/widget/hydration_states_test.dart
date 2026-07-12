import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/add_to_playlist_sheet.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/playlists/playlists_screen.dart';
import 'package:juzreviz/features/settings/settings_pages.dart';
import 'package:juzreviz/features/settings/settings_screen.dart';

class _DelayedJsonStore implements JsonStore {
  _DelayedJsonStore(this.delayedName);

  final String delayedName;
  final result = Completer<Map<String, dynamic>?>();

  @override
  Future<Map<String, dynamic>?> read(String name) {
    if (name == delayedName) return result.future;
    return Future.value();
  }

  @override
  Future<void> write(String name, Map<String, dynamic> data) async {}
}

Widget _app(JsonStore store, Widget child) => ProviderScope(
  overrides: [jsonStoreProvider.overrideWithValue(store)],
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('le profil attend les réglages au lieu d’afficher les défauts', (
    tester,
  ) async {
    final store = _DelayedJsonStore('settings');
    await tester.pumpWidget(_app(store, const SettingsScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Récitation'), findsNothing);

    store.result.complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Récitation'), findsOneWidget);
  });

  testWidgets('les playlists ne paraissent pas vides pendant leur chargement', (
    tester,
  ) async {
    final store = _DelayedJsonStore('playlists');
    await tester.pumpWidget(_app(store, const PlaylistsScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.textContaining('Crée une playlist'), findsNothing);

    store.result.complete({'playlists': <Object>[]});
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.textContaining('Crée une playlist'), findsOneWidget);
  });

  testWidgets('la feuille d’ajout attend les playlists avant ses actions', (
    tester,
  ) async {
    final store = _DelayedJsonStore('playlists');
    await tester.pumpWidget(
      _app(
        store,
        const Scaffold(body: AddToPlaylistSheet(selection: SelSurah(1, 1, 1))),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Aucune playlist pour l’instant.'), findsNothing);

    store.result.complete({'playlists': <Object>[]});
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Aucune playlist pour l’instant.'), findsOneWidget);
  });

  testWidgets('À propos ouvre la page des licences et notices', (tester) async {
    await tester.pumpWidget(_app(MemoryJsonStore(), const AboutPage()));

    await tester.tap(find.text('Licences et notices'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
