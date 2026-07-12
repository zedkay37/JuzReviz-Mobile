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
        final juz = _asInt(j['juz']);
        if (juz == null || juz < 1 || juz > 30) {
          throw const FormatException('Selection de juz invalide');
        }
        return SelJuz(juz);
      case 'review':
        final rawKeys = j['verseKeys'];
        if (rawKeys is! List) {
          throw const FormatException('Selection de revision invalide');
        }
        return SelReview(
          j['label'] is String ? j['label'] as String : '',
          rawKeys
              .whereType<String>()
              .where(_isCanonicalVerseKey)
              .toList(growable: false),
        );
      case 'surah':
        final surah = _asInt(j['surah']);
        final from = _asInt(j['from']);
        final to = _asInt(j['to']);
        if (surah == null ||
            from == null ||
            to == null ||
            surah < 1 ||
            surah > 114 ||
            from < 1 ||
            to < from ||
            to > 286) {
          throw const FormatException('Selection de sourate invalide');
        }
        return SelSurah(surah, from, to);
      default:
        throw const FormatException('Mode de selection inconnu');
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
  Map<String, dynamic> toJson() => {
    'mode': 'surah',
    'surah': surah,
    'from': from,
    'to': to,
  };

  @override
  String get label => from == to ? '$surah:$from' : '$surah:$from–$to';
}

class SelReview extends Selection {
  const SelReview(this.reviewLabel, this.verseKeys);
  final String reviewLabel;
  final List<String> verseKeys;

  @override
  Map<String, dynamic> toJson() => {
    'mode': 'review',
    'label': reviewLabel,
    'verseKeys': verseKeys,
  };

  @override
  String get label =>
      reviewLabel.isNotEmpty ? reviewLabel : '${verseKeys.length} versets';
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

bool _isCanonicalVerseKey(String value) {
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
