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
import 'package:juzreviz/main.dart';

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

class _FailingJsonStore implements JsonStore {
  @override
  Future<Map<String, dynamic>?> read(String name) =>
      Future.error(StateError('local storage unavailable'));

  @override
  Future<void> write(String name, Map<String, dynamic> data) async {}
}

Widget _app(JsonStore store, Widget child) => ProviderScope(
  overrides: [jsonStoreProvider.overrideWithValue(store)],
  child: MaterialApp(home: child),
);

void main() {
  testWidgets(
    'la racine attend les réglages avant de construire les parcours',
    (tester) async {
      final store = _DelayedJsonStore('settings');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const JuzRevizApp(),
        ),
      );
      await tester.pump();

      expect(find.text('JuzReviz'), findsOneWidget);
      expect(find.text('Aujourd’hui'), findsNothing);

      store.result.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aujourd’hui'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('l’erreur de démarrage reste utilisable en paysage à 200 %', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(568, 320);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(_FailingJsonStore())],
        child: const JuzRevizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
