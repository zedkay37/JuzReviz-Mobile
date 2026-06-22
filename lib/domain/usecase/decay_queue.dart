import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';

/// Entrée de la file « ce qui s'éteint ».
class QueueEntry {
  const QueueEntry(this.verseKey, this.state, this.count, this.ageMs);
  final String verseKey;
  final HeatState state;
  final int count;
  final int ageMs; // timestamp de référence (échec ou maîtrise) pour le tri
}

/// File de décroissance : tri par urgence (fragile > stale > fading),
/// puis difficulté (count desc), puis ancienneté (plus ancien d'abord).
/// [scopeKeys] restreint éventuellement le périmètre (sélection).
List<QueueEntry> buildDecayQueue(
  Map<String, Fragile> fragile,
  Map<String, Mastered> mastered,
  MasteryProfile profile,
  int now, {
  Iterable<String>? scopeKeys,
}) {
  final keys = scopeKeys?.toSet() ?? {...fragile.keys, ...mastered.keys};
  final out = <QueueEntry>[];
  for (final key in keys) {
    final f = fragile[key];
    final m = mastered[key];
    final state = verseHeatState(f, m, profile, now);
    if (state != HeatState.fragile &&
        state != HeatState.stale &&
        state != HeatState.fading) {
      continue;
    }
    final ref = state == HeatState.fragile
        ? (f?.markedAtMs ?? 0)
        : (m?.masteredAtMs ?? 0);
    out.add(QueueEntry(key, state, f?.count ?? 0, ref));
  }
  out.sort((a, b) {
    final u = stateUrgency[b.state]!.compareTo(stateUrgency[a.state]!);
    if (u != 0) return u;
    final c = b.count.compareTo(a.count);
    if (c != 0) return c;
    return a.ageMs.compareTo(b.ageMs); // plus ancien = plus urgent
  });
  return out;
}
