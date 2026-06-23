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
    (j['fragile'] as Map?)?.forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      fragile[k as String] = Fragile(
        (m['markedAtMs'] as num?)?.toInt() ?? 0,
        (m['count'] as num?)?.toInt() ?? 1,
      );
    });
    final mastered = <String, Mastered>{};
    (j['mastered'] as Map?)?.forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      mastered[k as String] = Mastered((m['masteredAtMs'] as num?)?.toInt() ?? 0);
    });
    return MasteryState(
      fragile: fragile,
      mastered: mastered,
      scarred: ((j['scarred'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      memorizedSurahs: ((j['memorizedSurahs'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toSet(),
      sessionDays: ((j['sessionDays'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
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
  }) =>
      MasteryState(
        fragile: fragile ?? this.fragile,
        mastered: mastered ?? this.mastered,
        scarred: scarred ?? this.scarred,
        memorizedSurahs: memorizedSurahs ?? this.memorizedSurahs,
        sessionDays: sessionDays ?? this.sessionDays,
      );
}
