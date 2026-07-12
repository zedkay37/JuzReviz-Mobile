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
  int now, {
  Set<String> manualScarred = const {},
}) {
  // Sourates cicatrisées : historique implicite ou marqueur manuel.
  final scarredSurahs = <int>{};
  for (final key in mastered.keys) {
    if (hasImplicitScar(fragile[key], mastered[key])) {
      scarredSurahs.add(int.parse(key.split(':')[0]));
    }
  }
  for (final key in manualScarred) {
    final surah = int.tryParse(key.split(':').first);
    if (surah != null) scarredSurahs.add(surah);
  }
  return metas
      .map(
        (m) => SurahHeatTile(
          m,
          surahHeat(m.number, m.ayahCount, fragile, mastered, profile, now),
          scarredSurahs.contains(m.number),
        ),
      )
      .toList(growable: false);
}
