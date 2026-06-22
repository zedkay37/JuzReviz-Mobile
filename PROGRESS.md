# PROGRESS — JuzReviz Mobile

Build : `flutter analyze` **0 issue** · `flutter test` **31/31 verts** · corpus généré
(6236 versets / 77 429 mots / 114 sourates, idempotent) · tafsir embarqué
(78 Mo → **8,2 Mo gzip**, lazy).

## Passe polish #2 — Tafsir (P7) + optimisation taille + décor

- **Tafsir complet (S45–S47)** : pipeline → `assets/tafsir/{fr,en}/{n}.json.gz`
  (gzip **déterministe**, MTIME/OS forcés → idempotent), `TafsirRepository`
  (décompression + parse lazy, cache) **testé**, `TafsirPanel` (typo parchemin,
  bascule FR/EN persistée, ouvre/ferme sans quitter la lecture), bouton **Tafsir**
  de la `CaptureBar` câblé (Reader + Drill), réglage langue du tafsir.
- **Optimisation taille** : 78,3 Mo de tafsir embarqués en **8,2 Mo** (≈9,5×),
  100 % offline. Manifest étendu (schema 2, tailles raw/gz).
- **Décor vivant (S63, opt-in)** : halo de braise `LanternAmbient` derrière le
  Reader, animé, **statique si Reduce motion**, gated `ambientDecor`.

## Passe polish / optimisation (2e run)

- **Moteur audio séquentiel** (Reader) : lecture enchaînée du passage, surlignage
  du verset actif, **auto-scroll** calé sur `scrollTempo`/amplitude, `autoMaster`
  (maîtrise en fin de dernière répétition), répétitions `off/ayah/range/progressive`
  via `expandPlayback` (pur, **testé**). → couvre S16 / S18 (verset) / S20.
- **Reprise réelle** : `scrollable_positioned_list` → scroll initial vers
  `currentVerseKey` + persistance debouncée du premier verset visible. → S10.
- **Perf** : `RepaintBoundary` par verset, `provider.select` (le Reader ne se
  reconstruit plus sur la persistance de reprise ni sur des réglages non liés),
  audio bar isolée en `ConsumerWidget`.
- **A11y + reduce-motion** : `Semantics` par verset (clé + traduction),
  `MediaQuery.disableAnimations` désactive les transitions du chrome. → S11/S65.
- **Adaptatif** : largeur de colonne bornée (≤720) sur tablette/paysage. → S66.
- **Zones chaudes** : bandeau top-5 sourates à revoir dans le Programme. → S38.
- **Onboarding** : coachmark one-time (gestes clés), persistant via `coachmarkSeen`. → S61.

## Fait (chemin critique P0→P6 + bases P9)

| Sprint | État | Notes |
|---|---|---|
| S0 Bootstrap | ✅ | `flutter create` android+ios, ProviderScope, structure couches |
| S1 Design tokens / thème | ✅ | `LanternTokens` (ThemeExtension) + 4 thèmes, typo/motion/space |
| S2 Police & ArabicText | ⚠️ | `ArabicText` RTL non-coupure OK ; police mushaf non embarquée (D3) |
| S3 Modèles domaine purs | ✅ | Verse/Word/SurahMeta/Selection/enums, round-trip testé |
| S4 Pipeline corpus | ✅ | `tools/build_corpus` → JSON + manifest, idempotent |
| S5 Accès corpus | ✅ | `CorpusRepository` (assets lazy) au lieu de Drift (D1) |
| S6 Réglages + Riverpod | ✅ | `Settings` sanitize + repo + providers, testé |
| S7 Use case lecture | ✅ | `readerVersesProvider` / `versesForSelection` |
| S8 ArabicVerse + sceau | ✅ | `AyahSeal` (chiffres arabes/latins), mots tappables |
| S9 InterlinearVerse | ✅ | gloses + traduction + toggles + langue, widget test |
| S10 Reader scroll | ✅ | `ListView` virtualisé, reprise `currentVerseKey` |
| S11 Scaffold immersif | ✅ | `LanternScaffold`, auto-hide chrome, focus mode |
| S12 Voile | ✅ | full / firstWords / hidden + révélation au tap |
| S13 Tajwid/a11y | ⚠️ | flag tajwid + Semantics ; coloration tajwid réelle à faire |
| S14–S17 Audio/cache | ⚠️ | `AudioController` + allowlist + récitateurs ; cache offline & bg à faire (D5) |
| S18–S20 Follow/bar | ⚠️ | audio bar OK ; karaoké mot en attente de données segments |
| S21 Atlas grille | ✅ | `HeatTile` + `atlasHeatProvider`, golden à ajouter |
| S22 Filtres/recherche | ✅ | mecquoise/médinoise/mémorisée + recherche pliée accents |
| S23 Vue Juz | ⚠️ | agrégat juz dispo (modèle) ; UI vue Juz à brancher |
| S24 Drill verset | ✅ | `SurahDrillScreen` grille `HeatCell`, tap→reader, long→capture |
| S25 Sélection→actions | ✅ | Lire / Ajouter playlist / (Réviser via Programme) |
| S27 Picker | ⚠️ | ajout playlist via sheet ; picker plage ayah complet à faire |
| S28 Algo + parité | ✅ | `mastery.dart` porté, table de parité verte |
| S29 Persistance état | ✅ | `MasteryRepository` + controller (F/M/clear/reset/memorized) |
| S30 Capture Reader | ✅ | `CaptureBar` appui long + haptique |
| S31 Cicatrice | ✅ | `EmberBadge` scarred, logique `verseFlag` testée |
| S32 Decay/probation | ✅ | appliqué Atlas/Drill, tests temps simulé |
| S33 File décroissance | ✅ | `buildDecayQueue` trié, testé |
| S34 Écran Programme | ✅ | file + état vide doux |
| S35 Micro-session | ✅ | `SessionScreen` runner F/M + résumé |
| S36 « 3 minutes » | ✅ | calibrage simple (15 versets) |
| S37 Streak | ✅ | `computeStreak`, testé |
| S40–S44 Playlists | ✅ | CRUD + détail + reorder + auto-avance + marqueur mémorisée |
| S56 Réglages écran | ✅ | sections Récitation/Lecture/Révision/Apparence/Données/À propos |
| S57 Thèmes | ✅ | Lanterne/Rawda/Parchemin/Contraste |
| S58 Dynamic color | ⚠️ | hook `dynamicColor` bridé prêt ; `dynamic_color` non branché |
| S60 Export/import | ✅ | JSON via presse-papiers + import merge |

## À faire (hors run automatisée — cf. DECISIONS D6)
- P7 Tafsir (panneau + données offline).
- P8 Surfaces natives : widgets Glance/WidgetKit, Quick Tile, bulle, notifications, deep links cold-start complets.
- Audio : cache offline (magic bytes mp3, move atomique), `audio_service` bg, audio-mot, karaoké.
- P10 polish : golden tests, décor vivant (shader), a11y complet, adaptatif tablette.
- P11 perf : cache mesure arabe, budgets, profiling.
- P12 sync Pro / P13 release stores / IAP.
- Police mushaf licenciée (D3).

## Restart handle
- **Changed** : projet Flutter complet sous `lib/` + `tools/build_corpus` + `assets/corpus` + tests.
- **Unverified** : build APK (lancé), audio réseau réel (offline-first par défaut).
- **Rollback** : `git reset --hard` (commit initial unique).
- **Do-not-touch** : `assets/corpus/*` (généré — régénérer via le pipeline), `mastery.dart` (parité desktop).
- **Next safe action** : brancher Tafsir (P7) ou cache audio offline (S17).
