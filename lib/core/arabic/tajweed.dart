import 'dart:ui' show Color;

/// Moteur tajwid — PUR (testable en `dart test`).
///
/// Couvre le sous-ensemble aux règles non ambiguës du texte uthmani
/// (convention couleur Dar Al-Maarifah : vert = ghunnah et assimilées,
/// rouge = madd obligatoire, bleu = qalqalah, gris = lettre non prononcée) :
///  - ghunnah : ن/م + shadda ;
///  - madd obligatoire : lettre portant la maddah ٓ ;
///  - qalqalah : ق ط ب ج د porteuse d'un sukun explicite ;
///  - noon sakinah / tanween : iqlab (petit meem ۢ/ۭ ou ب suivant),
///    idgham avec ghunnah (ينمو), idgham sans ghunnah (لر, gris),
///    ikhfa (15 lettres restantes) ;
///  - meem sakinah : ikhfa/idgham shafawi (devant ب ou م).
///
/// Le madd naturel (2 harakat) n'est volontairement pas coloré — comme dans
/// les mushafs tajwid imprimés.

enum TajweedRule { ghunnah, madd, qalqalah, silent }

/// Couleurs lisibles sur fond sombre comme sur parchemin.
const tajweedColors = <TajweedRule, Color>{
  TajweedRule.ghunnah: Color(0xFF66BB6A),
  TajweedRule.madd: Color(0xFFEF5350),
  TajweedRule.qalqalah: Color(0xFF64B5F6),
  TajweedRule.silent: Color(0xFF9E9E9E),
};

/// Segment de texte + règle éventuelle (null = couleur de base).
class TajweedSegment {
  const TajweedSegment(this.text, this.rule);
  final String text;
  final TajweedRule? rule;
}

const _sukun = 'ْ';
const _shadda = 'ّ';
const _maddah = 'ٓ';
const _smallMeem = 'ۢ'; // marque d'iqlab uthmani (haut)
const _smallMeemLow = 'ۭ'; // marque d'iqlab uthmani (bas)
const _tanween = {'ً', 'ٌ', 'ٍ'};
const _vowels = {'َ', 'ُ', 'ِ', 'ً', 'ٌ', 'ٍ'};
const _qalqalahLetters = {'ق', 'ط', 'ب', 'ج', 'د'};
const _idghamGhunnah = {'ي', 'ن', 'م', 'و'};
const _idghamNoGhunnah = {'ل', 'ر'};
const _ikhfa = {
  'ت', 'ث', 'ج', 'د', 'ذ', 'ز', 'س', 'ش',
  'ص', 'ض', 'ط', 'ظ', 'ف', 'ق', 'ك',
};

bool _isDiacritic(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x064B && code <= 0x065F) ||
      code == 0x0670 ||
      (code >= 0x06D6 && code <= 0x06ED);
}

/// Première lettre de base (non diacritique) d'un mot, '' si aucune.
String firstBaseLetter(String word) {
  for (var i = 0; i < word.length; i++) {
    final c = word[i];
    if (!_isDiacritic(c) && c != 'ٱ') return c;
  }
  return '';
}

/// Règle pour un noon sakinah / tanween selon la lettre suivante.
TajweedRule? _noonRule(String nextLetter) {
  if (nextLetter.isEmpty) return null;
  if (nextLetter == 'ب') return TajweedRule.ghunnah; // iqlab
  if (_idghamGhunnah.contains(nextLetter)) return TajweedRule.ghunnah;
  if (_idghamNoGhunnah.contains(nextLetter)) return TajweedRule.silent;
  if (_ikhfa.contains(nextLetter)) return TajweedRule.ghunnah; // ikhfa
  return null;
}

/// Découpe un mot uthmani en segments colorés.
/// [nextWord] : mot suivant du verset (règles inter-mots), null en fin.
List<TajweedSegment> tajweedSegments(String word, {String? nextWord}) {
  final out = <TajweedSegment>[];
  final nextInitial = nextWord == null ? '' : firstBaseLetter(nextWord);
  var i = 0;

  void emit(String text, TajweedRule? rule) {
    if (text.isEmpty) return;
    // Fusionne avec le segment précédent si même règle (moins de spans).
    if (out.isNotEmpty && out.last.rule == rule) {
      out[out.length - 1] = TajweedSegment(out.last.text + text, rule);
    } else {
      out.add(TajweedSegment(text, rule));
    }
  }

  while (i < word.length) {
    final c = word[i];
    // Groupe : lettre de base + tous ses diacritiques.
    var j = i + 1;
    while (j < word.length && _isDiacritic(word[j])) {
      j++;
    }
    final cluster = word.substring(i, j);
    final diacritics = cluster.substring(1);

    TajweedRule? rule;

    // آ précomposé (U+0622) ou maddah combinante : madd obligatoire.
    if (c == 'آ' || diacritics.contains(_maddah)) {
      rule = TajweedRule.madd;
    } else if ((c == 'ن' || c == 'م') && diacritics.contains(_shadda)) {
      rule = TajweedRule.ghunnah;
    } else if (_qalqalahLetters.contains(c) && diacritics.contains(_sukun)) {
      rule = TajweedRule.qalqalah;
    } else if (diacritics.contains(_smallMeem) ||
        diacritics.contains(_smallMeemLow)) {
      rule = TajweedRule.ghunnah; // iqlab marqué dans le texte
    } else if (c == 'ن' &&
        !diacritics.split('').any(_vowels.contains) &&
        !diacritics.contains(_shadda)) {
      // Noon sakinah (sukun explicite ou noon « nu » en uthmani).
      final following = j < word.length ? word[j] : nextInitial;
      rule = _noonRule(following);
    } else if (c == 'م' &&
        !diacritics.split('').any(_vowels.contains) &&
        !diacritics.contains(_shadda) &&
        !diacritics.contains(_sukun)) {
      // Meem sakinah nue : ikhfa/idgham shafawi devant ب ou م.
      final following = j < word.length ? word[j] : nextInitial;
      if (following == 'ب' || following == 'م') rule = TajweedRule.ghunnah;
    } else if (diacritics.split('').any(_tanween.contains)) {
      // Tanween : même famille de règles que noon sakinah.
      final following = j < word.length ? word[j] : nextInitial;
      rule = _noonRule(following);
    }

    emit(cluster, rule);
    i = j;
  }
  return out;
}
