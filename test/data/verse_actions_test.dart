import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/selection.dart';

ProviderContainer _container() => ProviderContainer(
      overrides: [jsonStoreProvider.overrideWithValue(MemoryJsonStore())],
    );

void main() {
  test('passageSelection : verset unique vs plage', () {
    expect(passageSelection('2:255'), const SelSurah(2, 255, 255));
    expect(passageSelection('18:1', '18:10'), const SelSurah(18, 1, 10));
  });

  test('MasteryState round-trip conserve les cicatrices', () {
    const s = MasteryState(scarred: {'2:255', '18:1'});
    final back = MasteryState.fromJson(s.toJson());
    expect(back.scarred, {'2:255', '18:1'});
  });

  test('togglePassage est idempotent (ajout puis retrait)', () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(playlistsControllerProvider.notifier);
    await c.read(playlistsControllerProvider.future);
    final p = await ctrl.create('Test');
    const sel = SelSurah(2, 255, 255);

    await ctrl.togglePassage(p.id, sel);
    var pl = c.read(playlistsControllerProvider).value!.first;
    expect(playlistHasPassage(pl, sel), isTrue);
    expect(pl.items.length, 1);

    await ctrl.togglePassage(p.id, sel);
    pl = c.read(playlistsControllerProvider).value!.first;
    expect(playlistHasPassage(pl, sel), isFalse);
    expect(pl.items, isEmpty);
  });

  test('createWithPassage crée la playlist avec le passage', () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(playlistsControllerProvider.notifier);
    await c.read(playlistsControllerProvider.future);

    await ctrl.createWithPassage('Kahf', const SelSurah(18, 1, 10));
    final lists = c.read(playlistsControllerProvider).value!;
    expect(lists.single.name, 'Kahf');
    expect(lists.single.items.single.selection, const SelSurah(18, 1, 10));
  });

  test('createWithSelections crée une playlist multi-passages', () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(playlistsControllerProvider.notifier);
    await c.read(playlistsControllerProvider.future);

    await ctrl.createWithSelections('Révision', const [
      SelSurah(90, 1, 20),
      SelSurah(112, 1, 4),
      SelJuz(30),
    ]);
    final pl = c.read(playlistsControllerProvider).value!.single;
    expect(pl.name, 'Révision');
    expect(pl.items.length, 3);
    expect(pl.items.first.selection, const SelSurah(90, 1, 20));
    expect(pl.items.last.selection, const SelJuz(30));
  });

  test('toggleScar pose puis retire la cicatrice', () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(masteryControllerProvider.notifier);
    await c.read(masteryControllerProvider.future);

    await ctrl.toggleScar('2:255');
    expect(c.read(masteryControllerProvider).value!.scarred, contains('2:255'));

    await ctrl.toggleScar('2:255');
    expect(c.read(masteryControllerProvider).value!.scarred, isEmpty);
  });

  test('hasImplicitScar reste pur (parité inchangée)', () {
    expect(hasImplicitScar(null, Mastered(1000)), isFalse);
  });

  test('seedKnownSurahs : petit lot (< cap) → tout dû dès aujourd’hui',
      () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(masteryControllerProvider.notifier);
    await c.read(masteryControllerProvider.future);
    final now = c.read(clockProvider).nowMs();

    await ctrl.seedKnownSurahs({1: 7});
    final s = c.read(masteryControllerProvider).value!;

    expect(s.memorizedSurahs, {1});
    expect(s.mastered.length, 7);
    // 7 versets < la vague journalière (20) : aucun n'attend le lendemain.
    for (var a = 1; a <= 7; a++) {
      expect(
        verseHeatState(null, s.mastered['1:$a'], MasteryProfile.serenity, now),
        isNot(HeatState.fresh),
        reason: '1:$a devrait être dû aujourd’hui',
      );
    }
  });

  test('seedKnownSurahs : gros lot → vague du jour garantie, reste étalé',
      () async {
    final c = _container();
    addTearDown(c.dispose);
    final ctrl = c.read(masteryControllerProvider.notifier);
    await c.read(masteryControllerProvider.future);
    final now = c.read(clockProvider).nowMs();

    // 100 versets (5 sourates de 20) : bien plus que la vague de 20/jour.
    await ctrl.seedKnownSurahs({for (var n = 1; n <= 5; n++) n: 20});
    final s = c.read(masteryControllerProvider).value!;
    expect(s.mastered.length, 100);

    // La première vague (20 premiers versets, sourate 1 entière) est due
    // aujourd'hui — pas un seul verset isolé.
    var dueToday = 0;
    for (var a = 1; a <= 20; a++) {
      if (verseHeatState(null, s.mastered['1:$a'], MasteryProfile.serenity,
              now) !=
          HeatState.fresh) {
        dueToday++;
      }
    }
    expect(dueToday, 20);

    // Le tout dernier verset (vague la plus lointaine) est encore frais.
    expect(
      verseHeatState(null, s.mastered['5:20'], MasteryProfile.serenity, now),
      HeatState.fresh,
    );
  });
}
