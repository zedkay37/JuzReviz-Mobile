import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/usecase/decay_queue.dart';
import 'package:juzreviz/domain/usecase/streak.dart';

const day = 86400000;
const now = 1700000000000;
int daysAgo(int d) => now - d * day;

void main() {
  test('file triée fragile > stale > fading puis difficulté', () {
    final fragile = {
      '2:1': Fragile(daysAgo(1), 1), // fragile
      '2:5': Fragile(daysAgo(400), 4), // échec ancien mais récent vs maîtrise ? non maîtrisé → fragile
    };
    final mastered = {
      '2:2': Mastered(daysAgo(400)), // stale
      '2:3': Mastered(daysAgo(200)), // fading
      '2:4': Mastered(daysAgo(5)), // fresh → exclu
    };
    final q = buildDecayQueue(fragile, mastered, MasteryProfile.serenity, now);
    final keys = q.map((e) => e.verseKey).toList();
    expect(keys, contains('2:1'));
    expect(keys, isNot(contains('2:4'))); // fresh exclu
    // Premier = fragile (urgence max)
    expect(q.first.state, HeatState.fragile);
    // stale avant fading
    final stale = keys.indexOf('2:2');
    final fading = keys.indexOf('2:3');
    expect(stale < fading, isTrue);
  });

  group('streak', () {
    test('jours consécutifs', () {
      final days = {dayKey(now), dayKey(now - day), dayKey(now - 2 * day)};
      expect(computeStreak(days, now), 3);
    });

    test('tolérance hier', () {
      final days = {dayKey(now - day)};
      expect(computeStreak(days, now), 1);
    });

    test('rupture → 0', () {
      final days = {dayKey(now - 3 * day)};
      expect(computeStreak(days, now), 0);
    });
  });
}
