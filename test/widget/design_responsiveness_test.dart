import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/decay_queue.dart';
import 'package:juzreviz/features/atlas/atlas_screen.dart';
import 'package:juzreviz/features/program/known_surahs_sheet.dart';
import 'package:juzreviz/features/program/program_screen.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

Future<void> _pumpAt200Percent(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
  double viewInsetsBottom = 0,
  Size size = const Size(320, 568),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  Widget app = MaterialApp(
    theme: buildTheme(AppTheme.lanterne),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(2),
        viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
      ),
      child: child!,
    ),
    home: home,
  );
  if (overrides.isNotEmpty) {
    app = ProviderScope(overrides: overrides, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un état vide reste utilisable sur petit écran à 200 %', (
    tester,
  ) async {
    await _pumpAt200Percent(
      tester,
      LanternScaffold(
        appBar: AppBar(title: const Text('Playlists')),
        body: LanternEmpty(
          message:
              'Crée une playlist pour regrouper tes passages de lecture ou de révision.',
          icon: Icons.queue_music,
          action: FilledButton(
            onPressed: () {},
            child: const Text('Nouvelle playlist'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Nouvelle playlist'), findsOneWidget);
  });

  testWidgets('SliderRow accepte un long libellé à 200 % sans overflow', (
    tester,
  ) async {
    await _pumpAt200Percent(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: SliderRow(
            title: 'Pause après chaque âyah',
            value: 1,
            min: 0,
            max: 3,
            divisions: 3,
            valueLabel: '1,0 s',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pause après chaque âyah'), findsOneWidget);
  });

  testWidgets('la sélection initiale reste utilisable à 200 %', (tester) async {
    const metas = [
      SurahMeta(
        number: 1,
        ayahCount: 7,
        arabicName: 'الفاتحة',
        transliteration: 'Al-Fatiha',
        englishName: 'The Opening',
        revelation: Revelation.meccan,
        hasSajda: false,
        juzStart: 1,
      ),
      SurahMeta(
        number: 114,
        ayahCount: 6,
        arabicName: 'الناس',
        transliteration: 'An-Nas',
        englishName: 'Mankind',
        revelation: Revelation.meccan,
        hasSajda: false,
        juzStart: 30,
      ),
    ];
    await _pumpAt200Percent(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showKnownSurahsSheet(context),
              child: const Text('Commencer'),
            ),
          ),
        ),
      ),
      overrides: [surahMetasProvider.overrideWith((_) async => metas)],
      viewInsetsBottom: 260,
    );

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Valider (1)'), findsNothing);
    expect(find.text('Coche au moins une sourate'), findsOneWidget);
  });

  testWidgets('le programme reste défilable en paysage à 200 %', (
    tester,
  ) async {
    final store = MemoryJsonStore();
    await store.write('mastery', {
      'fragile': {
        '1:1': {'markedAtMs': 1, 'count': 2},
      },
      'mastered': <String, Object>{},
      'scarred': <String>[],
      'memorizedSurahs': [1],
      'sessionDays': <String>[],
    });
    await _pumpAt200Percent(
      tester,
      const ProgramScreen(),
      size: const Size(568, 320),
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        surahMetasProvider.overrideWith(
          (_) async => const [
            SurahMeta(
              number: 1,
              ayahCount: 7,
              arabicName: 'الفاتحة',
              transliteration: 'Al-Fatiha',
              englishName: 'The Opening',
              revelation: Revelation.meccan,
              hasSajda: false,
              juzStart: 1,
            ),
          ],
        ),
        decayQueueProvider.overrideWith(
          (_) async => const [QueueEntry('1:1', HeatState.fragile, 2, 1)],
        ),
        streakProvider.overrideWith((_) async => 3),
        hotZonesProvider.overrideWith((_) async => const []),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Session rapide'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('l’Atlas reste utilisable avec clavier en paysage à 200 %', (
    tester,
  ) async {
    await _pumpAt200Percent(
      tester,
      const Scaffold(body: AtlasGridView()),
      size: const Size(568, 320),
      viewInsetsBottom: 180,
      overrides: [
        jsonStoreProvider.overrideWithValue(MemoryJsonStore()),
        atlasHeatProvider.overrideWith((_) async => const []),
        reviewSummaryProvider.overrideWith((_) async => (count: 0, minutes: 0)),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Aucune sourate ne correspond.'), findsOneWidget);
  });
}
