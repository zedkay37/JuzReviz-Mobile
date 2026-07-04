import 'dart:math' as math;

import 'package:juzreviz/domain/model/enums.dart';

/// Algorithme de « chaleur » fragile / maîtrise — PUR et testable (`dart test`).
///
/// Porté à l'identique du desktop (`JuzReviz2/src/core/mastery.ts`).
/// Aucune donnée dérivée n'est stockée : la maîtrise refroidit avec le temps.
/// L'horloge (`now`, epoch ms) est toujours injectée — jamais de `DateTime.now()`.

class _Thresholds {
  const _Thresholds(this.freshDays, this.fadingDays);
  final double freshDays;
  final double fadingDays;
}

_Thresholds _thresholds(MasteryProfile p) => switch (p) {
      MasteryProfile.serenity => const _Thresholds(180, 365),
      MasteryProfile.excellence => const _Thresholds(30, 90),
    };

const double _dayMs = 86400000;

/// Jours de « fraîcheur » avant qu'un verset maîtrisé redevienne à revoir
/// (sans échec). Utilisé par l'ensemencement pour étaler les échéances.
double freshDaysFor(MasteryProfile p) => _thresholds(p).freshDays;

double daysSince(int epochMs, int now) =>
    epochMs <= 0 ? double.infinity : math.max(0, (now - epochMs) / _dayMs);

/// Refroidissement accéléré par difficulté (`failureCount`) + probation (>= 5).
HeatState _decayState(
  int masteredAtMs,
  MasteryProfile p,
  int now,
  int failureCount,
) {
  final base = _thresholds(p);
  final factor = math.min(2.5, 1 + failureCount * 0.15);
  var fresh = base.freshDays / factor;
  final fading = base.fadingDays / factor;
  if (failureCount >= 5) {
    fresh = math.min(fresh, p == MasteryProfile.excellence ? 3.0 : 7.0);
  }
  final age = daysSince(masteredAtMs, now);
  if (age < fresh) return HeatState.fresh;
  if (age < fading) return HeatState.fading;
  return HeatState.stale;
}

class Fragile {
  const Fragile(this.markedAtMs, this.count);
  final int markedAtMs;
  final int count;
}

class Mastered {
  const Mastered(this.masteredAtMs);
  final int masteredAtMs;
}

/// État par RÉCENCE : le plus récent entre dernier échec et dernière maîtrise gagne.
HeatState verseHeatState(
  Fragile? fragile,
  Mastered? mastered,
  MasteryProfile profile,
  int now,
) {
  if (fragile == null && mastered == null) return HeatState.blank;
  if (fragile != null && mastered == null) return HeatState.fragile;
  final count = fragile?.count ?? 0;
  if (mastered != null && fragile == null) {
    return _decayState(mastered.masteredAtMs, profile, now, count);
  }
  return fragile!.markedAtMs > mastered!.masteredAtMs
      ? HeatState.fragile
      : _decayState(mastered.masteredAtMs, profile, now, count);
}

/// Cicatrice implicite : le verset est aujourd'hui maîtrisé (non fragile)
/// mais a déjà connu un échec par le passé. Combinée en display avec la
/// cicatrice manuelle (`MasteryState.scarred`) — les deux sont des métadonnées
/// d'historique, pas un état de mémorisation à part entière.
bool hasImplicitScar(Fragile? fragile, Mastered? mastered) {
  if (mastered == null) return false;
  if ((fragile?.count ?? 0) == 0) return false;
  return fragile == null || mastered.masteredAtMs >= fragile.markedAtMs;
}

const Map<HeatState, int> stateUrgency = {
  HeatState.fragile: 4,
  HeatState.stale: 3,
  HeatState.fading: 2,
  HeatState.fresh: 1,
  HeatState.blank: 0,
};

const Map<HeatState, double> _stateWeight = {
  HeatState.fresh: 1,
  HeatState.fading: 0.6,
  HeatState.stale: 0.25,
  HeatState.fragile: 0,
  HeatState.blank: 0,
};

/// Agrégat sourate pour l'Atlas.
class SurahHeat {
  const SurahHeat({
    required this.warmth,
    required this.hasFragile,
    required this.needsReview,
    required this.total,
    required this.dominant,
  });

  final double warmth;
  final bool hasFragile;
  final int needsReview;
  final int total;
  final HeatState dominant;
}

/// Agrège l'état des ayahs 1..[verseCount] d'une sourate.
SurahHeat surahHeat(
  int surahNumber,
  int verseCount,
  Map<String, Fragile> fragile,
  Map<String, Mastered> mastered,
  MasteryProfile profile,
  int now,
) {
  var sum = 0.0;
  var hasFragile = false;
  var needsReview = 0;
  var dominant = HeatState.blank;
  for (var ayah = 1; ayah <= verseCount; ayah++) {
    final key = '$surahNumber:$ayah';
    final state =
        verseHeatState(fragile[key], mastered[key], profile, now);
    sum += _stateWeight[state]!;
    if (state == HeatState.fragile) hasFragile = true;
    if (state == HeatState.fragile ||
        state == HeatState.stale ||
        state == HeatState.fading) {
      needsReview++;
    }
    if (stateUrgency[state]! > stateUrgency[dominant]!) dominant = state;
  }
  return SurahHeat(
    warmth: verseCount > 0 ? sum / verseCount : 0,
    hasFragile: hasFragile,
    needsReview: needsReview,
    total: verseCount,
    dominant: dominant,
  );
}
