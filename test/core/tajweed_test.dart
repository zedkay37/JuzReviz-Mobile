import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/core/arabic/tajweed.dart';

void main() {
  TajweedRule? ruleAt(List<TajweedSegment> segs, String letter) {
    for (final s in segs) {
      if (s.text.contains(letter)) return s.rule;
    }
    return null;
  }

  test('mot neutre → aucun segment coloré', () {
    final segs = tajweedSegments('بِسْمِ');
    expect(segs.every((s) => s.rule == null), isTrue);
  });

  test('ghunnah : noon + shadda (إِنَّ)', () {
    final segs = tajweedSegments('إِنَّ');
    expect(ruleAt(segs, 'ن'), TajweedRule.ghunnah);
  });

  test('madd obligatoire : maddah (ءَآمَنُوا۟ style جَآءَ)', () {
    final segs = tajweedSegments('جَآءَ');
    expect(segs.any((s) => s.rule == TajweedRule.madd), isTrue);
  });

  test('qalqalah : ب + sukun (يَبْتَغِ)', () {
    final segs = tajweedSegments('يَبْتَغِ');
    expect(ruleAt(segs, 'ب'), TajweedRule.qalqalah);
  });

  test('idgham sans ghunnah : noon sakinah devant ر → silent (مِن رَّبِّهِمْ)',
      () {
    final segs = tajweedSegments('مِن', nextWord: 'رَّبِّهِمْ');
    expect(ruleAt(segs, 'ن'), TajweedRule.silent);
  });

  test('ikhfa : tanween devant س (mot suivant)', () {
    final segs = tajweedSegments('عَذَابٌ', nextWord: 'سَيِّئٌ');
    expect(segs.any((s) => s.rule == TajweedRule.ghunnah), isTrue);
  });

  test('idgham avec ghunnah : noon sakinah devant م (مِن مَّسَدٍ)', () {
    final segs = tajweedSegments('مِّن', nextWord: 'مَّسَدِۭ');
    expect(ruleAt(segs, 'ن'), TajweedRule.ghunnah);
  });

  test('la concaténation des segments restitue le mot exact', () {
    for (final w in ['بِسْمِ', 'إِنَّ', 'جَآءَ', 'يَبْتَغِ', 'عَذَابٌ', 'مِّن']) {
      final segs = tajweedSegments(w);
      expect(segs.map((s) => s.text).join(), w);
    }
  });
}
