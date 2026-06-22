import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/domain/model/word.dart';
import 'package:juzreviz/features/reader/widgets/interlinear_verse.dart';

Verse _verse() => const Verse(
      surah: 1,
      ayah: 1,
      verseKey: '1:1',
      juz: 1,
      arabic: 'بِسْمِ ٱللَّهِ',
      translationFr: 'Au nom de Dieu',
      translationEn: 'In the name of God',
      words: [
        Word(
          verseKey: '1:1',
          position: 1,
          arabic: 'بِسْمِ',
          glossFr: 'Au nom',
          glossEn: 'In the name',
          translit: 'bismi',
          isWaqf: false,
        ),
        Word(
          verseKey: '1:1',
          position: 2,
          arabic: 'ٱللَّهِ',
          glossFr: 'de Dieu',
          glossEn: 'of God',
          translit: 'llahi',
          isWaqf: false,
        ),
      ],
    );

void main() {
  testWidgets('InterlinearVerse affiche gloses + traduction et émet le tap mot',
      (tester) async {
    var tapped = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: InterlinearVerse(
            verse: _verse(),
            onWordTap: (p) => tapped = p,
          ),
        ),
      ),
    ));

    expect(find.text('Au nom'), findsOneWidget);
    expect(find.text('Au nom de Dieu'), findsOneWidget);

    await tester.tap(find.text('Au nom'));
    expect(tapped, 1);
  });
}
