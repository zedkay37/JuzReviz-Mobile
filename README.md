# JuzReviz Mobile

> **« Le Coran qui vit dans ta journée. »** — mushaf interlinéaire premium + révision
> SRS invisible (fragile/maîtrise), offline-first. Flutter (Android + iOS).

Voir [SPEC.md](SPEC.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md)
· [PROGRESS.md](PROGRESS.md) · [DECISIONS.md](DECISIONS.md).

## État

`flutter analyze` : **0 issue** · `flutter test` : **suite verte** ·
`flutter build apk --debug` : **OK** · corpus : **6236 versets / 77 429 mots /
114 sourates** (généré, idempotent).

Chemin critique **P0→P6** + bases réglages/thèmes opérationnels : Reader interlinéaire,
Atlas heatmap, Programme SRS + micro-sessions, Playlists, Réglages.

## Démarrer

```bash
flutter pub get
# (re)générer le corpus depuis le desktop JuzReviz2 (chemin par défaut Windows) :
dart run tools/build_corpus/build_corpus.dart --source ../JuzReviz2
flutter run
```

## Architecture (couches)

`features/* → domain → data/* → core/*`. Le dossier `domain/` est **pur Dart**
(zéro import Flutter, testable) : modèles + `mastery.dart` (algo de chaleur porté
à l'identique du desktop, sous test de parité) + use cases.

- `core/` : design system « Lanterne » (tokens `ThemeExtension`, composants), rendu
  arabe RTL, routing go_router, horloge injectable.
- `data/` : corpus (assets lazy), état de révision/playlists/réglages (JSON local),
  audio (allowlist + just_audio).
- `features/` : reader, atlas, program, playlists, settings.

## Corpus & données

Pipeline `tools/build_corpus/build_corpus.dart` (Dart pur) : lit Tanzil uthmani +
métadonnées sourates/juz/sajda + gloses word-by-word du desktop → `assets/corpus/`
+ `manifest.json` (hash FNV-1a, déterministe). Texte uthmani : Tanzil Project
(CC BY 3.0, notice embarquée). Les licences et provenances exactes des gloses,
traductions et tafsirs doivent rester documentées avant toute distribution.

La progression est stockée localement, sans compte, publicité ni SDK de suivi.
Le cœur textuel fonctionne hors ligne ; les téléchargements audio et Mushaf
contactent leurs hébergeurs en HTTPS.

## Tests

```bash
flutter test
```

Couvre : parité de l'algorithme de maîtrise, file de décroissance, streak,
sanitisation des réglages, round-trip Selection, rendu InterlinearVerse.
