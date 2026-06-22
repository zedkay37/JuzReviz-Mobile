# DECISIONS — écarts de périmètre assumés

> Toute décision diverge d'`ARCHITECTURE.md` est notée ici (cf. ROADMAP « Suivi »).

## D1 — Persistance : assets JSON + JSON local au lieu de Drift/SQLite
**Contexte.** L'architecture prévoit Drift (SQLite) prépeuplé + tables d'état.
**Décision.** Pour livrer un build vert sans codegen ni dépendance native sqlite
au runtime/tests :
- **Corpus** = assets JSON normalisés, chargés en lazy par sourate
  (`assets/corpus/surah/{n}.json` + `surah_meta.json` + `manifest.json`),
  générés par le pipeline `tools/build_corpus`.
- **État** (fragile/maîtrise/mémorisées/sessions, playlists, réglages) = fichiers
  JSON via `path_provider`, modèles immuables, exposés en Riverpod.
**Conséquence.** Les *interfaces repository* (`CorpusRepository`, `MasteryRepository`,
`PlaylistsRepository`, `SettingsRepository`) sont stables : un backend Drift peut
les réimplémenter plus tard sans toucher domaine/features. Volumes concernés
(quelques centaines d'entrées d'état) ne justifient pas SQLite à ce stade.

## D2 — State management sans codegen
`riverpod_generator`/`freezed`/`json_serializable` remplacés par des providers
Riverpod manuels (`AsyncNotifierProvider`) et des modèles immuables écrits à la
main (`copyWith`/`fromJson`/`toJson`). Objectif : zéro `build_runner`, compilation
déterministe en une run. Réintroductibles sans rupture d'API.

## D3 — Police arabe système (pas de mushaf embarqué)
`assets/fonts/` non peuplé : aucune police KFGQPC sous licence disponible dans la
run. `ArabicText`/`arabicFamily` pointent sur la police système (rendu RTL correct,
non-coupure au niveau mot assurée par le layout `Wrap` interlinéaire). À remplacer
au S2 par une police mushaf licenciée → `arabicFamily` dans les tokens.

## D4 — `flutter_lints` au lieu de `very_good_analysis`
`very_good_analysis` impose des règles (docs API publiques…) qui généreraient des
centaines d'infos. On part de `flutter_lints` + quelques règles ajoutées
(`prefer_single_quotes`, `directives_ordering`, `avoid_print`). `flutter analyze`
= **0 issue**. Durcissable plus tard.

## D5 — Audio sans `audio_service` (just_audio seul)
La lecture arrière-plan (`audio_service` + service Android/Background modes iOS)
exige une config native non automatisable en une run. `AudioController`
(just_audio) lit un verset depuis une source **validée par allowlist**. Le timing
mot (audio-follow karaoké S18/S19) attend des données de segments non présentes
dans le corpus desktop → surlignage au niveau verset seulement pour l'instant.

## D6 — Hors périmètre d'une run (documenté dans PROGRESS.md)
Surfaces natives (widgets Glance/WidgetKit, Quick Tile, bulle), IAP, sync Pro,
release stores, golden tests image, recettes appareil. Nécessitent appareils,
signing, comptes stores.
