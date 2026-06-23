import 'package:juzreviz/domain/model/surah_meta.dart';

/// Bornes canoniques des 30 juz : `(sourate, ayah)` de début de chaque juz.
const juzStarts = <(int, int)>[
  (1, 1), (2, 142), (2, 253), (3, 93), (4, 24),
  (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
  (9, 93), (11, 6), (12, 53), (15, 1), (17, 1),
  (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
  (29, 46), (33, 31), (36, 28), (39, 32), (41, 47),
  (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
];

/// Clés de versets d'un juz (1..30), de sa borne de début à la borne suivante.
List<String> juzVerseKeys(int juz, List<SurahMeta> metas) {
  if (juz < 1 || juz > 30) return const [];
  final start = juzStarts[juz - 1];
  final next = juz < 30 ? juzStarts[juz] : null;
  final ayahOf = {for (final m in metas) m.number: m.ayahCount};
  final out = <String>[];
  var s = start.$1;
  var a = start.$2;
  while (s <= 114) {
    if (next != null && (s > next.$1 || (s == next.$1 && a >= next.$2))) break;
    final count = ayahOf[s] ?? 0;
    if (a > count) {
      s++;
      a = 1;
      continue;
    }
    out.add('$s:$a');
    a++;
  }
  return out;
}

/// Toutes les clés de versets du Coran (1:1 … 114:n), dans l'ordre.
List<String> quranVerseKeys(List<SurahMeta> metas) => [
      for (final m in metas)
        for (var a = 1; a <= m.ayahCount; a++) '${m.number}:$a',
    ];
