/// Clé de jour `yyyy-mm-dd`. Le domaine reste déterministe en UTC par défaut ;
/// l'application passe [local] pour respecter le jour civil de l'utilisateur.
String dayKey(int epochMs, {bool local = false}) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: !local);
  return _dateKey(d);
}

String _dateKey(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Jours consécutifs (jusqu'à aujourd'hui inclus) avec au moins une session.
int computeStreak(Set<String> sessionDays, int nowMs, {bool local = false}) {
  if (sessionDays.isEmpty) return 0;
  if (local) return _computeLocalStreak(sessionDays, nowMs);
  const dayMs = 86400000;
  var streak = 0;
  var cursor = nowMs;
  // Tolérance : si pas de session aujourd'hui mais hier, le streak vaut hier.
  if (!sessionDays.contains(dayKey(cursor))) {
    cursor -= dayMs;
    if (!sessionDays.contains(dayKey(cursor))) return 0;
  }
  while (sessionDays.contains(dayKey(cursor))) {
    streak++;
    cursor -= dayMs;
  }
  return streak;
}

int _computeLocalStreak(Set<String> sessionDays, int nowMs) {
  final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
  var cursor = DateTime(now.year, now.month, now.day);

  if (!sessionDays.contains(_dateKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    if (!sessionDays.contains(_dateKey(cursor))) return 0;
  }

  var streak = 0;
  while (sessionDays.contains(_dateKey(cursor))) {
    streak++;
    // Construction calendaire : respecte les jours de 23/25 h autour du DST.
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}
