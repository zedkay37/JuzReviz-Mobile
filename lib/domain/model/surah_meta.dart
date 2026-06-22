import 'package:juzreviz/domain/model/enums.dart';

/// Métadonnées d'une sourate.
class SurahMeta {
  const SurahMeta({
    required this.number,
    required this.ayahCount,
    required this.arabicName,
    required this.transliteration,
    required this.englishName,
    required this.revelation,
    required this.hasSajda,
    required this.juzStart,
  });

  factory SurahMeta.fromMap(Map<String, dynamic> m) => SurahMeta(
        number: (m['number'] as num).toInt(),
        ayahCount: (m['ayahCount'] as num).toInt(),
        arabicName: (m['arabicName'] ?? '') as String,
        transliteration: (m['transliteration'] ?? '') as String,
        englishName: (m['englishName'] ?? '') as String,
        revelation: revelationFromString((m['revelation'] ?? 'meccan') as String),
        hasSajda: (m['hasSajda'] ?? false) as bool,
        juzStart: (m['juzStart'] as num?)?.toInt() ?? 1,
      );

  final int number;
  final int ayahCount;
  final String arabicName;
  final String transliteration;
  final String englishName;
  final Revelation revelation;
  final bool hasSajda;
  final int juzStart;

  String get label => '$number. $transliteration';
}
