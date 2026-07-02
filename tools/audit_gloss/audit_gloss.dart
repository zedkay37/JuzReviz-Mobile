// Audit qualité des gloses FR du corpus (PLAN.md R1.1).
//
// Détecte dans `words[].fr` des 114 sourates :
//  1. des tokens anglais (mots qui n'existent pas en français) ;
//  2. des typos connues / motifs suspects (mots collés fréquents).
//
// Usage :  dart run tools/audit_gloss/audit_gloss.dart [--json]
// Sortie : liste `verseKey pos "glose"` triée, + comptes par sourate.
// Ne modifie rien — lecture seule.

import 'dart:convert';
import 'dart:io';

/// Tokens strictement anglais (jamais des mots français valides).
/// Volontairement conservateur : pas de mots ambigus (ex. `on`, `me`, `a`).
const english = <String>{
  'the', 'of', 'and', 'is', 'are', 'was', 'were', 'they', 'them', 'their',
  'this', 'these', 'those', 'who', 'whom', 'whose', 'which', 'when', 'where',
  'why', 'how', 'will', 'would', 'shall', 'should', 'could', 'may', 'might',
  'has', 'have', 'had', 'not', 'from', 'with', 'without', 'upon', 'among',
  'because', 'before', 'after', 'above', 'under', 'over', 'into', 'unto',
  'then', 'than', 'there', 'here', 'his', 'her', 'him', 'its', 'our', 'your',
  'yours', 'my', 'we', 'all', 'any', 'both', 'each', 'every', 'other',
  'another', 'such', 'only', 'also', 'very', 'more', 'most', 'much', 'many',
  'few', 'own', 'said', 'say', 'says', 'do', 'does', 'did', 'been', 'being',
  'having', 'what', 'you', 'yourselves', 'themselves', 'himself', 'herself',
  'itself', 'ourselves', 'be', 'by', 'at', 'so', 'if', 'it',
  'he', 'she', 'us', 'to', 'in', 'that', 'grazing', 'livestock', 'quadruped',
  'cattle', 'indeed', 'lord', 'people', 'day', 'earth', 'heaven',
  'heavens', 'believe', 'believers', 'disbelievers', 'punishment', 'guidance',
  'mercy', 'merciful', 'knowing', 'wise', 'mighty', 'except', 'until',
};

/// Typos connues → correction attendue (repérées visuellement, sourate 5).
const knownTypos = <String, String>{
  'pérmis': 'permis',
  'décréte': 'décrète',
  'faitclicite': 'félicite',
};

void main(List<String> args) {
  final asJson = args.contains('--json');
  final findings = <Map<String, Object>>[];
  final perSurah = <int, int>{};

  for (var s = 1; s <= 114; s++) {
    final f = File('assets/corpus/surah/$s.json');
    if (!f.existsSync()) {
      stderr.writeln('ABSENT: sourate $s');
      continue;
    }
    final verses = jsonDecode(f.readAsStringSync()) as List;
    for (final v in verses) {
      final verse = (v as Map).cast<String, dynamic>();
      final words = (verse['words'] as List?) ?? const [];
      for (final w in words) {
        final word = (w as Map).cast<String, dynamic>();
        final fr = (word['fr'] as String?) ?? '';
        if (fr.isEmpty) continue;
        final issues = <String>[];

        // Tokens : lettres (accents inclus) uniquement, minuscule.
        final tokens = RegExp(r"[a-zA-ZÀ-ÿ']+")
            .allMatches(fr.toLowerCase())
            .map((m) => m.group(0)!.replaceAll("'", ''))
            .where((t) => t.length > 1);
        for (final t in tokens) {
          if (english.contains(t)) issues.add('anglais:$t');
          if (knownTypos.containsKey(t)) issues.add('typo:$t→${knownTypos[t]}');
        }

        // Élisions manquantes : « le or », « de eux »… (fautes FR).
        // Les mots à h aspiré ne s'élident pas (« se hâter », « le Hajj »).
        const hAspire = <String>{
          'hâter', 'hâte', 'hâtent', 'hâtez', 'haut', 'haute', 'hauts',
          'hautes', 'héros', 'huit', 'honte', 'hors', 'haine', 'haïr',
          'hésite', 'hésitent', 'hajj', 'honteux', 'honteuse', 'honteuses',
        };
        final elision = RegExp(
          r'\b(le|la|de|que|ne|se|ce|je|me|te)\s+\[?\(?'
          r'([aeiouyâàéèêëîïôùûhAEIOUYÂÉÈÊÎÔH][\wà-ÿÀ-ÿ’-]*)',
        );
        for (final m in elision.allMatches(fr)) {
          final w = m.group(2)!.toLowerCase();
          if (w.startsWith('h') && hAspire.contains(w)) continue;
          issues.add('élision:«${m.group(0)}»');
        }

        if (issues.isNotEmpty) {
          perSurah[s] = (perSurah[s] ?? 0) + 1;
          findings.add({
            'verseKey': verse['verseKey'],
            'position': word['position'],
            'fr': fr,
            'issues': issues,
          });
        }
      }
    }
  }

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(findings));
  } else {
    for (final f in findings) {
      stdout.writeln(
          '${f['verseKey']}#${f['position']}  "${f['fr']}"  [${(f['issues'] as List).join(', ')}]');
    }
    stdout.writeln('---');
    stdout.writeln('Total gloses suspectes : ${findings.length}');
    final sorted = perSurah.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(15)) {
      stdout.writeln('  sourate ${e.key} : ${e.value}');
    }
  }
  exitCode = findings.isEmpty ? 0 : 1;
}
