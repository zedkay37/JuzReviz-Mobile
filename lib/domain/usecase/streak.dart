/// Clé de jour (UTC) `yyyy-mm-dd` pour le streak (déterministe en test).
String dayKey(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

const _dayMs = 86400000;

/// Jours consécutifs (jusqu'à aujourd'hui inclus) avec au moins une session.
int computeStreak(Set<String> sessionDays, int nowMs) {
  if (sessionDays.isEmpty) return 0;
  var streak = 0;
  var cursor = nowMs;
  // Tolérance : si pas de session aujourd'hui mais hier, le streak vaut hier.
  if (!sessionDays.contains(dayKey(cursor))) {
    cursor -= _dayMs;
    if (!sessionDays.contains(dayKey(cursor))) return 0;
  }
  while (sessionDays.contains(dayKey(cursor))) {
    streak++;
    cursor -= _dayMs;
  }
  return streak;
}
