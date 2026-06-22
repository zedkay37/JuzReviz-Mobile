/// Un mot d'un verset, aligné sur l'audio-mot (`position` 1-based).
class Word {
  const Word({
    required this.verseKey,
    required this.position,
    required this.arabic,
    required this.glossFr,
    required this.glossEn,
    required this.translit,
    required this.isWaqf,
  });

  factory Word.fromMap(String verseKey, Map<String, dynamic> m) => Word(
        verseKey: verseKey,
        position: (m['position'] as num).toInt(),
        arabic: (m['ar'] ?? '') as String,
        glossFr: (m['fr'] ?? '') as String,
        glossEn: (m['en'] ?? '') as String,
        translit: (m['tr'] ?? '') as String,
        isWaqf: (m['isWaqf'] ?? false) as bool,
      );

  final String verseKey;
  final int position;
  final String arabic;
  final String glossFr;
  final String glossEn;
  final String translit;
  final bool isWaqf;

  String gloss(String lang) => lang == 'en' ? glossEn : glossFr;
}
