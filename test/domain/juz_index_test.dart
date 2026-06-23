import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/juz_index.dart';

SurahMeta _m(int n, int count) => SurahMeta(
      number: n,
      ayahCount: count,
      arabicName: '',
      transliteration: 'S$n',
      englishName: '',
      revelation: Revelation.meccan,
      hasSajda: false,
      juzStart: 1,
    );

void main() {
  final metas = [_m(1, 7), _m(2, 286)];

  test('juz 1 va de 1:1 à 2:141 (148 versets)', () {
    final keys = juzVerseKeys(1, metas);
    expect(keys.length, 148);
    expect(keys.first, '1:1');
    expect(keys.last, '2:141');
    expect(keys.contains('2:142'), isFalse);
  });

  test('juz hors bornes → vide', () {
    expect(juzVerseKeys(0, metas), isEmpty);
    expect(juzVerseKeys(31, metas), isEmpty);
  });

  test('quranVerseKeys concatène toutes les sourates', () {
    final keys = quranVerseKeys(metas);
    expect(keys.length, 7 + 286);
    expect(keys.first, '1:1');
    expect(keys.last, '2:286');
  });
}
