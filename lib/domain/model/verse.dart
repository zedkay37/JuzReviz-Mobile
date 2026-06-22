import 'package:juzreviz/domain/model/word.dart';

/// Un verset du corpus (read-only).
class Verse {
  const Verse({
    required this.surah,
    required this.ayah,
    required this.verseKey,
    required this.juz,
    required this.arabic,
    required this.translationFr,
    required this.translationEn,
    required this.words,
  });

  factory Verse.fromMap(Map<String, dynamic> m) {
    final key = m['verseKey'] as String;
    final parts = key.split(':');
    final wordList = (m['words'] as List? ?? const [])
        .map((w) => Word.fromMap(key, (w as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return Verse(
      surah: int.parse(parts[0]),
      ayah: int.parse(parts[1]),
      verseKey: key,
      juz: (m['juz'] as num).toInt(),
      arabic: (m['arabic'] ?? '') as String,
      translationFr: (m['fr'] ?? '') as String,
      translationEn: (m['en'] ?? '') as String,
      words: wordList,
    );
  }

  final int surah;
  final int ayah;
  final String verseKey;
  final int juz;
  final String arabic;
  final String translationFr;
  final String translationEn;
  final List<Word> words;

  String translation(String lang) => lang == 'en' ? translationEn : translationFr;
}
