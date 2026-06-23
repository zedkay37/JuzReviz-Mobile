import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/mushaf/mushaf_page.dart';

void main() {
  test('parseMushafPage lit en-tête, basmala et ligne d’ayât', () {
    final page = parseMushafPage([
      {'line': 1, 'type': 'surah', 'surah': 2},
      {'line': 2, 'type': 'basmalah'},
      {
        'line': 3,
        'type': 'ayah',
        'centered': false,
        'words': [
          {'c': 'ﭑ', 'k': '2:1'},
          {'c': 'ﭒ', 'k': '2:1'},
        ],
      },
    ]);

    expect(page.length, 3);
    expect(page[0].type, MushafLineType.surahHeader);
    expect(page[0].surah, 2);
    expect(page[1].type, MushafLineType.basmalah);
    expect(page[2].type, MushafLineType.ayah);
    expect(page[2].words.length, 2);
    expect(page[2].words.first.glyph, 'ﭑ');
    expect(page[2].words.first.verseKey, '2:1');
  });

  test('valeurs manquantes → défauts sûrs', () {
    final page = parseMushafPage([
      {'type': 'ayah'},
    ]);
    expect(page.single.line, 0);
    expect(page.single.words, isEmpty);
    expect(page.single.centered, isFalse);
  });
}
