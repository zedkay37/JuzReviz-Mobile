/// Modèle de mise en page « moushaf Madani » (format QPC v1/v2).
///
/// Une page = 15 lignes. Chaque ligne est soit un en-tête de sourate, soit la
/// basmala, soit une ligne d'ayât (suite de mots-glyphes rendus avec la police
/// QCF de la page). Le rendu est piloté par [MushafView].
enum MushafLineType { surahHeader, basmalah, ayah }

class MushafWord {
  const MushafWord({required this.glyph, required this.verseKey});

  /// Glyphe encodé dans la police QCF de la page (un ou quelques codepoints).
  final String glyph;

  /// Clé du verset auquel le mot appartient (`"2:255"`), pour tap/surlignage.
  final String verseKey;

  factory MushafWord.fromJson(Map<String, dynamic> j) => MushafWord(
        glyph: (j['c'] ?? '') as String,
        verseKey: (j['k'] ?? '') as String,
      );
}

class MushafLine {
  const MushafLine({
    required this.line,
    required this.type,
    this.surah,
    this.centered = false,
    this.words = const [],
  });

  final int line;
  final MushafLineType type;

  /// Numéro de sourate (en-tête).
  final int? surah;

  /// Ligne centrée (début de sourate, lignes courtes).
  final bool centered;
  final List<MushafWord> words;

  factory MushafLine.fromJson(Map<String, dynamic> j) => MushafLine(
        line: (j['line'] as num?)?.toInt() ?? 0,
        type: switch (j['type']) {
          'surah' => MushafLineType.surahHeader,
          'basmalah' => MushafLineType.basmalah,
          _ => MushafLineType.ayah,
        },
        surah: (j['surah'] as num?)?.toInt(),
        centered: (j['centered'] ?? false) as bool,
        words: ((j['words'] as List?) ?? const [])
            .map((e) => MushafWord.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );
}

/// Parse une page (liste de lignes) depuis le JSON `pages["<n>"]`.
List<MushafLine> parseMushafPage(List<dynamic> raw) => raw
    .map((e) => MushafLine.fromJson((e as Map).cast<String, dynamic>()))
    .toList(growable: false);
