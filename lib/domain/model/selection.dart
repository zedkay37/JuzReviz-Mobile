import 'dart:convert';

/// Sélection sérialisable (playlists, reprise, deep links).
///
/// Variantes : `juz(n)`, `surah(n, from, to)`, `review(label, verseKeys)`.
sealed class Selection {
  const Selection();

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is Selection && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;

  factory Selection.fromJson(Map<String, dynamic> j) {
    switch (j['mode']) {
      case 'juz':
        return SelJuz((j['juz'] as num).toInt());
      case 'review':
        return SelReview(
          (j['label'] ?? '') as String,
          ((j['verseKeys'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
        );
      case 'surah':
      default:
        return SelSurah(
          (j['surah'] as num).toInt(),
          (j['from'] as num).toInt(),
          (j['to'] as num).toInt(),
        );
    }
  }

  Map<String, dynamic> toJson();

  /// Libellé court lisible (UI, label de playlist).
  String get label;
}

class SelJuz extends Selection {
  const SelJuz(this.juz);
  final int juz;

  @override
  Map<String, dynamic> toJson() => {'mode': 'juz', 'juz': juz};

  @override
  String get label => 'Juz $juz';
}

class SelSurah extends Selection {
  const SelSurah(this.surah, this.from, this.to);
  final int surah;
  final int from;
  final int to;

  @override
  Map<String, dynamic> toJson() =>
      {'mode': 'surah', 'surah': surah, 'from': from, 'to': to};

  @override
  String get label =>
      from == to ? '$surah:$from' : '$surah:$from–$to';
}

class SelReview extends Selection {
  const SelReview(this.reviewLabel, this.verseKeys);
  final String reviewLabel;
  final List<String> verseKeys;

  @override
  Map<String, dynamic> toJson() =>
      {'mode': 'review', 'label': reviewLabel, 'verseKeys': verseKeys};

  @override
  String get label =>
      reviewLabel.isNotEmpty ? reviewLabel : '${verseKeys.length} versets';
}
