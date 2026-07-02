// Correction par lots des gloses FR (PLAN.md R1.1) — compagnon de
// audit_gloss.dart.
//
// Deux étages :
//  1. Table manuelle (verseKey#position) pour les restes anglais purs.
//  2. Règle d'élision française déterministe :
//     « le/la/de/que/ne/se/ce/je/me/te + voyelle » → « l'/d'/qu'… »,
//     avec pluriel (le/la/de + nom en -s/-x → les/des), h aspiré et
//     pronoms gérés en exceptions.
//
// Usage :
//   dart run tools/audit_gloss/fix_gloss.dart          (dry-run, rapport)
//   dart run tools/audit_gloss/fix_gloss.dart --apply  (écrit les fichiers)

import 'dart:convert';
import 'dart:io';

/// Corrections manuelles : 'verseKey#position' → nouvelle glose.
const manual = <String, String>{
  '11:61#27': 'Celui qui exauce',
  '11:73#13': '(est) Digne de louange',
  '11:107#13': '(est) Celui qui accomplit',
  '51:58#4': '(est) le Grand Pourvoyeur',
  '81:4#2': 'les chamelles pleines',
  '89:3#2': 'et l’impair',
  '89:18#2': 'vous incitez (mutuellement)',
  '107:3#2': 'incite',
  '83:26#6': 'les aspirants',
  '79:46#1': 'Comme s’ils',
  '3:14#11': '[l’]or',
};

/// h aspiré : pas d'élision (« se hâter », « le haut », « le Hajj »).
const hAspire = <String>{
  'hâter', 'hâte', 'hâtent', 'hâtez', 'haut', 'haute', 'hauts', 'hautes',
  'héros', 'huit', 'honte', 'hors', 'haine', 'haïr', 'hésite', 'hésitent',
  'hajj', 'honteux', 'honteuse', 'honteuses',
};

/// Singuliers finissant par s/x : élision, pas « les ».
/// Inclut les adjectifs en -eux (« de heureux » → « d'heureux », pas « des »).
const singulierEnS = <String>{
  'univers', 'avis', 'os', 'ours', 'paradis',
  'heureux', 'malheureux', 'généreux', 'nombreux', 'pieux', 'envieux',
  'orgueilleux', 'miséricordieux', 'affreux', 'odieux',
};

/// Pronoms : élision directe, jamais « les » (« que ils » → « qu'ils »).
const pronoms = <String>{'il', 'ils', 'elle', 'elles', 'on', 'un', 'une', 'eux'};

const _elide = <String, String>{
  'le': 'l’', 'la': 'l’', 'de': 'd’', 'que': 'qu’', 'ne': 'n’',
  'se': 's’', 'ce': 'c’', 'je': 'j’', 'me': 'm’', 'te': 't’',
};

final _pattern = RegExp(
  r'\b(le|la|de|que|ne|se|ce|je|me|te)(\s+)(\(?\[?)'
  r'([aeiouyâàéèêëîïôùûhAEIOUYÂÀÉÈÊËÎÏÔÙÛH][\wà-ÿÀ-ÿ’-]*)',
  caseSensitive: false,
);

String fixElisions(String fr) {
  final out = fr.replaceAllMapped(_pattern, (m) {
    final det = m.group(1)!;
    final bracket = m.group(3)!;
    final word = m.group(4)!;
    final wLower = word.toLowerCase();
    final detLower = det.toLowerCase();

    if (wLower.startsWith('h') && hAspire.contains(wLower)) return m.group(0)!;

    final isPronoun = pronoms.contains(wLower);
    final looksPlural = !isPronoun &&
        (wLower.endsWith('s') || wLower.endsWith('x')) &&
        wLower.length > 3 &&
        !singulierEnS.contains(wLower);

    if (looksPlural) {
      // « le étoiles » → « les étoiles » ; « de Affaires » → « des Affaires ».
      final plural = switch (detLower) {
        'le' || 'la' => 'les',
        'de' => 'des',
        _ => null,
      };
      if (plural != null) {
        final p = det[0] == det[0].toUpperCase()
            ? plural[0].toUpperCase() + plural.substring(1)
            : plural;
        return '$p ${bracket}$word';
      }
    }

    var apo = _elide[detLower]!;
    if (det[0] == det[0].toUpperCase()) {
      apo = apo[0].toUpperCase() + apo.substring(1);
    }
    return '$apo$bracket$word';
  });
  // Second étage : « de les » n'est jamais correct en français → « des ».
  return out
      .replaceAll(RegExp(r'\bde les\b'), 'des')
      .replaceAll(RegExp(r'\bDe les\b'), 'Des');
}

void main(List<String> args) {
  final apply = args.contains('--apply');
  var changed = 0;
  final samples = <String>[];

  for (var s = 1; s <= 114; s++) {
    final file = File('assets/corpus/surah/$s.json');
    final verses = jsonDecode(file.readAsStringSync()) as List;
    var dirty = false;

    for (final v in verses) {
      final verse = (v as Map).cast<String, dynamic>();
      final key = verse['verseKey'] as String;
      for (final w in (verse['words'] as List? ?? const [])) {
        final word = (w as Map).cast<String, dynamic>();
        final fr = (word['fr'] as String?) ?? '';
        if (fr.isEmpty) continue;

        final id = '$key#${word['position']}';
        final next = manual[id] ?? fixElisions(fr);
        if (next != fr) {
          changed++;
          dirty = true;
          word['fr'] = next;
          if (samples.length < 400) samples.add('$id  "$fr" → "$next"');
        }
      }
    }

    if (dirty && apply) {
      file.writeAsStringSync(jsonEncode(verses));
    }
  }

  samples.forEach(stdout.writeln);
  stdout.writeln('---');
  stdout.writeln(
      '${apply ? 'APPLIQUÉ' : 'DRY-RUN'} : $changed gloses corrigées.');
}
