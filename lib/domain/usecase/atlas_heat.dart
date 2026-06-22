import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';

class SurahHeatTile {
  const SurahHeatTile(this.meta, this.heat, this.scarred);
  final SurahMeta meta;
  final SurahHeat heat;
  final bool scarred;
}

/// Calcule la chaleur de chaque sourate (Atlas) + présence de cicatrices.
List<SurahHeatTile> buildAtlasHeat(
  List<SurahMeta> metas,
  Map<String, Fragile> fragile,
  Map<String, Mastered> mastered,
  MasteryProfile profile,
  int now,
) {
  // Sourates cicatrisées : maîtrisé avec count > 0 (O(mastered)).
  final scarredSurahs = <int>{};
  for (final key in mastered.keys) {
    final flag = verseFlag(fragile[key], mastered[key]);
    if (flag.scarred) scarredSurahs.add(int.parse(key.split(':')[0]));
  }
  return metas
      .map((m) => SurahHeatTile(
            m,
            surahHeat(
                m.number, m.ayahCount, fragile, mastered, profile, now),
            scarredSurahs.contains(m.number),
          ))
      .toList(growable: false);
}

/// Chaleur agrégée par juz (Atlas vue Juz).
class JuzHeat {
  const JuzHeat(this.juz, this.warmth, this.hasFragile, this.needsReview,
      this.dominant);
  final int juz;
  final double warmth;
  final bool hasFragile;
  final int needsReview;
  final HeatState dominant;
}
