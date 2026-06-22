import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';

const day = 86400000;
const now = 1700000000000; // base d'horloge fixe

int daysAgo(int d) => now - d * day;

void main() {
  group('verseHeatState — parité desktop', () {
    test('aucune donnée → blank', () {
      expect(verseHeatState(null, null, MasteryProfile.serenity, now),
          HeatState.blank);
    });

    test('fragile seul → fragile', () {
      expect(
          verseHeatState(Fragile(daysAgo(1), 1), null,
              MasteryProfile.serenity, now),
          HeatState.fragile);
    });

    test('maîtrisé récent (sérénité) → fresh', () {
      expect(
          verseHeatState(null, Mastered(daysAgo(10)),
              MasteryProfile.serenity, now),
          HeatState.fresh);
    });

    test('maîtrisé 200j (sérénité) → fading', () {
      expect(
          verseHeatState(null, Mastered(daysAgo(200)),
              MasteryProfile.serenity, now),
          HeatState.fading);
    });

    test('maîtrisé 400j (sérénité) → stale', () {
      expect(
          verseHeatState(null, Mastered(daysAgo(400)),
              MasteryProfile.serenity, now),
          HeatState.stale);
    });

    test('les deux, échec plus récent → fragile', () {
      expect(
          verseHeatState(Fragile(daysAgo(1), 2), Mastered(daysAgo(5)),
              MasteryProfile.serenity, now),
          HeatState.fragile);
    });

    test('les deux, maîtrise plus récente, jeune → fresh', () {
      expect(
          verseHeatState(Fragile(daysAgo(10), 2), Mastered(daysAgo(2)),
              MasteryProfile.serenity, now),
          HeatState.fresh);
    });

    test('probation count>=5 (excellence) borne fresh à 3j', () {
      // factor = min(2.5, 1+5*0.15)=1.75 ; fresh=min(30/1.75, 3)=3 ; fading=90/1.75≈51.4
      expect(
          verseHeatState(Fragile(daysAgo(40), 5), Mastered(daysAgo(2)),
              MasteryProfile.excellence, now),
          HeatState.fresh);
      expect(
          verseHeatState(Fragile(daysAgo(40), 5), Mastered(daysAgo(4)),
              MasteryProfile.excellence, now),
          HeatState.fading);
    });
  });

  group('verseFlag — cicatrice', () {
    test('maîtrisé avec échecs passés → scarred', () {
      final flag = verseFlag(Fragile(daysAgo(10), 3), Mastered(daysAgo(2)));
      expect(flag.state, FlagState.mastered);
      expect(flag.scarred, isTrue);
      expect(flag.failureCount, 3);
    });

    test('maîtrisé sans échec → non scarred', () {
      final flag = verseFlag(null, Mastered(daysAgo(2)));
      expect(flag.scarred, isFalse);
    });

    test('échec plus récent → fragile, non scarred', () {
      final flag = verseFlag(Fragile(daysAgo(1), 1), Mastered(daysAgo(5)));
      expect(flag.state, FlagState.fragile);
      expect(flag.scarred, isFalse);
    });
  });

  group('surahHeat', () {
    test('agrège warmth / hasFragile / dominant', () {
      final fragile = {'2:1': Fragile(daysAgo(1), 1)};
      final mastered = {'2:2': Mastered(daysAgo(2))};
      final heat =
          surahHeat(2, 3, fragile, mastered, MasteryProfile.serenity, now);
      expect(heat.total, 3);
      expect(heat.hasFragile, isTrue);
      expect(heat.dominant, HeatState.fragile);
      expect(heat.needsReview, greaterThanOrEqualTo(1));
      expect(heat.warmth, greaterThan(0));
    });
  });
}
