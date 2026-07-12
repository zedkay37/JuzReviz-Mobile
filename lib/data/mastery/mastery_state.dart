import 'package:juzreviz/domain/mastery/mastery.dart';

/// État de révision persistable (fragile / maîtrise / mémorisées / sessions).
class MasteryState {
  const MasteryState({
    this.fragile = const {},
    this.mastered = const {},
    this.scarred = const {},
    this.memorizedSurahs = const {},
    this.sessionDays = const {},
  });

  factory MasteryState.fromJson(Map<String, dynamic> j) {
    final fragile = <String, Fragile>{};
    final rawFragile = j['fragile'];
    if (rawFragile is Map) {
      for (final entry in rawFragile.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || !_isVerseKey(key) || value is! Map) continue;
        final markedAt = value['markedAtMs'];
        final count = value['count'];
        fragile[key] = Fragile(
          markedAt is num ? markedAt.toInt().clamp(0, 1 << 62) : 0,
          count is num ? count.toInt().clamp(1, 9999) : 1,
        );
      }
    }
    final mastered = <String, Mastered>{};
    final rawMastered = j['mastered'];
    if (rawMastered is Map) {
      for (final entry in rawMastered.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || !_isVerseKey(key) || value is! Map) continue;
        final masteredAt = value['masteredAtMs'];
        mastered[key] = Mastered(
          masteredAt is num ? masteredAt.toInt().clamp(0, 1 << 62) : 0,
        );
      }
    }
    final rawScarred = j['scarred'];
    final rawMemorized = j['memorizedSurahs'];
    final rawDays = j['sessionDays'];
    return MasteryState(
      fragile: fragile,
      mastered: mastered,
      scarred: rawScarred is List
          ? rawScarred.whereType<String>().where(_isVerseKey).toSet()
          : const {},
      memorizedSurahs: rawMemorized is List
          ? rawMemorized
                .whereType<num>()
                .map((e) => e.toInt())
                .where((n) => n >= 1 && n <= 114)
                .toSet()
          : const {},
      sessionDays: rawDays is List
          ? rawDays.whereType<String>().where(_isDayKey).toSet()
          : const {},
    );
  }

  final Map<String, Fragile> fragile;
  final Map<String, Mastered> mastered;

  /// Cicatrices posées manuellement (badge permanent, indépendant du déclin).
  final Set<String> scarred;
  final Set<int> memorizedSurahs;
  final Set<String> sessionDays;

  Map<String, dynamic> toJson() => {
    'fragile': {
      for (final e in fragile.entries)
        e.key: {'markedAtMs': e.value.markedAtMs, 'count': e.value.count},
    },
    'mastered': {
      for (final e in mastered.entries)
        e.key: {'masteredAtMs': e.value.masteredAtMs},
    },
    'scarred': scarred.toList()..sort(),
    'memorizedSurahs': memorizedSurahs.toList()..sort(),
    'sessionDays': sessionDays.toList()..sort(),
  };

  MasteryState copyWith({
    Map<String, Fragile>? fragile,
    Map<String, Mastered>? mastered,
    Set<String>? scarred,
    Set<int>? memorizedSurahs,
    Set<String>? sessionDays,
  }) => MasteryState(
    fragile: fragile ?? this.fragile,
    mastered: mastered ?? this.mastered,
    scarred: scarred ?? this.scarred,
    memorizedSurahs: memorizedSurahs ?? this.memorizedSurahs,
    sessionDays: sessionDays ?? this.sessionDays,
  );
}

bool _isVerseKey(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return false;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  return surah != null &&
      ayah != null &&
      surah >= 1 &&
      surah <= 114 &&
      ayah >= 1 &&
      ayah <= 286;
}

bool _isDayKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  return DateTime.tryParse(value) != null;
}
