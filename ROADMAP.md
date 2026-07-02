> **ARCHIVE** — Roadmap d'origine, référence des intentions initiales.
> L'app a divergé (nav 4 onglets, état unifié, écran Réciter dédié).
> Source de vérité : le code + [PLAN.md](PLAN.md).

# JuzReviz Mobile (Flutter) — Roadmap exécutable (phases → sprints → jalons)

> **Format d'un jalon** : chaque sprint `Sx` a un **Objectif**, des **Livrables**,
> des **Critères d'acceptation** (vérifiables) et une **Vérif** (commande/test/golden).
> Un sprint = un commit atomique `type(scope): … (Sx)`. Un sprint n'est « fait » que
> si sa Vérif passe.
>
> **Definition of Done globale** : build vert (`flutter build`) · tests du sprint
> verts (`flutter test`) · `flutter analyze` sans erreur · aucune régression des
> golden tests · pas de réseau requis au démarrage · DoD spécifiques respectées.

## Carte des phases

| Phase | Thème | Sprints | Sortie |
|---|---|---|---|
| **P0** | Fondations & data | S0–S6 | Squelette buildable + corpus en base |
| **P1** | Lecteur interlinéaire (flagship) | S7–S13 | Reader lisible offline |
| **P2** | Audio & follow | S14–S20 | Lecture bg + karaoké + cache offline |
| **P3** | Atlas & sélection | S21–S27 | Heatmap + picker + drill |
| **P4** | Modèle fragile/maîtrise | S28–S33 | Capture + decay + parité desktop |
| **P5** | Programme du jour (SRS) | S34–S39 | Micro-sessions + streak |
| **P6** | Playlists | S40–S44 | CRUD + auto-avance |
| **P7** | Tafsir | S45–S47 | Panneau tafsir offline |
| **P8** | Surfaces interstitielles | S48–S55 | Widgets + notif + tuile (+ bulle Android) |
| **P9** | Réglages & thèmes | S56–S60 | Thèmes lanterne + dynamic + données |
| **P10** | Design polish, motion, a11y | S61–S66 | Niveau premium |
| **P11** | Offline complet & perf | S67–S71 | Budgets + zéro jank |
| **P12** | Sync/compte Pro (option) | S72–S76 | Backup/sync chiffré |
| **P13** | Release stores | S77–S82 | Prod signée Play + App Store |

> P0→P5 = **chemin critique** (produit utilisable). P6→P13 incrémentales,
> réordonnables. Découper un sprint en `Sx.a/Sx.b` est autorisé tant que chaque
> sous-jalon garde un critère vérifiable.

---

## P0 — Fondations & data

### S0 — Bootstrap projet
- **Objectif** : app Flutter buildable, conventions en place.
- **Livrables** : `flutter create` (Android+iOS) ; `ProviderScope` racine ; `very_good_analysis` ; `dart format` ; structure de dossiers (core/data/domain/features) ; CI GitHub Actions (analyze+test+build).
- **Acceptation** : `flutter run` ouvre un écran « Lanterne » vide sur Android et iOS (sim) ; `flutter analyze` zéro erreur.
- **Vérif** : CI verte (analyze + test + build apk).

### S1 — Design tokens & thème Lanterne
- **Objectif** : socle visuel.
- **Livrables** : `core/designsystem` — tokens couleur (Lanterne nuit) via `ThemeExtension`, échelle typo, formes, élévations, specs motion ; `lanternTheme` (Material 3) ; dark par défaut ; police latine variable.
- **Acceptation** : écran démo palette + échelle typo ; bascule thème système respectée.
- **Vérif** : golden de la palette stable (`golden_toolkit`).

### S2 — Police arabe & primitive de rendu
- **Objectif** : afficher l'arabe correctement.
- **Livrables** : police mushaf embarquée (+ licence) ; widget `ArabicText` RTL ; test de non-coupure harakat ; **décision** primitive (texte natif vs glyphes pré-rendus) selon golden.
- **Acceptation** : un verset long s'affiche sans couper mot ni harakat, à plusieurs largeurs.
- **Vérif** : golden `ArabicText` (large/étroit) verts.

### S3 — Modèles de domaine purs
- **Objectif** : `domain/model`.
- **Livrables** : `Verse`, `Word`, `SurahMeta`, `Selection`, enums (`Revelation`, `MasteryProfile`, `HeatState`) en `freezed` — **sans import Flutter**.
- **Acceptation** : `dart test` pur passe ; round-trip JSON de `Selection`.
- **Vérif** : `dart test test/domain/model`.

### S4 — Pipeline corpus → base prépeuplée
- **Objectif** : transformer la data desktop en base mobile.
- **Livrables** : `tools/build_corpus` (lit `JuzReviz2/public/data/words/*.json` + métas) → `corpus.db` (verse/word/surah_meta + index) + manifest (hash/tailles) ; copie police/licences.
- **Acceptation** : `corpus.db` contient 6236 versets et 114 sourates ; manifest listé ; idempotent (2 runs = même hash).
- **Vérif** : script de contrôle (compte versets/mots) + diff hash double run = 0.

### S5 — Drift + accès corpus
- **Objectif** : lire le corpus depuis l'app.
- **Livrables** : `data/db` Drift — ouverture de `corpus.db` (copie asset → fichier), tables read-only, DAO (`versesBySurah`, `versesByJuz`, `verseByKey`, `wordsByVerse`, `surahMeta`) ; tables d'état (fragile/mastered/playlist/memorized/audio_cache) + DAO mutables ; migrations.
- **Acceptation** : « versets de la sourate 2 » renvoie 286 versets avec mots ordonnés.
- **Vérif** : tests DAO (Drift in-memory + asset).

### S6 — Réglages (JSON + sanitize) + Riverpod
- **Objectif** : réglages persistés + DI.
- **Livrables** : modèle `Settings` (`freezed`) mapping `ARCHITECTURE §4`, défauts garantis ; `SettingsRepository` (JSON path_provider, `Stream`) ; providers Riverpod racine.
- **Acceptation** : modifier un réglage le persiste et le réémet ; défauts corrects au 1er lancement ; clé inconnue ignorée proprement.
- **Vérif** : tests `SettingsRepository` (sanitize + round-trip).

---

## P1 — Lecteur interlinéaire (flagship)

### S7 — Repo corpus + use case lecture
- **Livrables** : `CorpusRepository` ; `GetReaderVersesUseCase(selection)` → versets + mots.
- **Acceptation** : `Surah(2,1,7)` renvoie 7 versets complets (gloses FR/EN + translit).
- **Vérif** : tests use case (fake repo).

### S8 — ArabicVerse : arabe + sceau d'ayah
- **Livrables** : `ArabicVerse` (mots tappables, sceau d'ayah stylisé, chiffres arabes/latins).
- **Acceptation** : rendu d'un verset avec numéro ; tap mot émet la position (1-based correcte).
- **Vérif** : widget test (tap → position) + golden.

### S9 — InterlinearVerse : gloses + traduction
- **Livrables** : `InterlinearVerse` (glose sous chaque mot, traduction sous le verset) ; toggles mot-à-mot/traduction + langue.
- **Acceptation** : toggles modifient le rendu ; FR/EN respecté ; alignement mot↔glose correct (waqf inclus).
- **Vérif** : golden (4 combinaisons toggles) + widget test toggles.

### S10 — Reader screen + scroll multi-versets
- **Livrables** : `features/reader` écran + controller Riverpod (UDF) ; `ListView.builder` virtualisé ; reprise sur `currentVerseKey`.
- **Acceptation** : scroll fluide sourate 2 (286 v.) ; position sauvegardée/restaurée.
- **Vérif** : test perf (timeline jank) + test reprise.

### S11 — LanternScaffold + immersif auto-hide
- **Livrables** : scaffold edge-to-edge, `SafeArea`/insets, chrome auto-hide (ex-calmChrome) ; Focus mode (immersif total).
- **Acceptation** : contrôles s'effacent au repos, réapparaissent au tap ; Focus masque tout sauf le texte ; Reduce motion respecté.
- **Vérif** : widget tests (auto-hide, focus toggle).

### S12 — Voile (auto-test)
- **Livrables** : modes `full`/`firstWords(n)`/`hidden` ; révélation au tap.
- **Acceptation** : `firstWords(3)` montre 3 mots, masque le reste ; tap révèle progressivement.
- **Vérif** : widget tests des 3 modes.

### S13 — Tajwid + chiffres latins + a11y de base
- **Livrables** : coloration tajwid optionnelle ; sémantique (Semantics) arabe/gloses ; cibles ≥ 48 dp.
- **Acceptation** : tajwid on/off ; lecteur d'écran lit verset + traduction ; contraste AA.
- **Vérif** : test sémantique + golden tajwid.

---

## P2 — Audio & follow

### S14 — just_audio + audio_service
- **Livrables** : `data/audio` + `AudioHandler` (`audio_service`) ; lecture d'un verset (réseau, allowlist).
- **Acceptation** : play/pause d'un verset ; lecture arrière-plan + contrôles lockscreen/casque.
- **Vérif** : test handler (états) ; recette bg documentée.

### S15 — Sélection récitateur + vitesse
- **Livrables** : liste récitateurs ; `playbackRate` 0.5–2×.
- **Acceptation** : changer de récitateur recharge la source ; vitesse sans pitch cassé.
- **Vérif** : tests controller audio.

### S16 — Répétition (ayah/range/progressif)
- **Livrables** : moteur de répétition (count, rangeCount, pause), progressif (∞ interdit → coerce 3).
- **Acceptation** : reproduit la sémantique desktop (N×M, pause inter-répétitions, invalidation progressive sur navigation).
- **Vérif** : tests unitaires du moteur (table de cas alignée desktop).

### S17 — Cache audio offline
- **Livrables** : téléchargement verset (tmp unique, magic bytes mp3, move atomique), index Drift, lecture locale prioritaire, purge.
- **Acceptation** : un verset téléchargé lit **sans réseau** ; fichier corrompu rejeté ; purge libère l'espace.
- **Vérif** : tests cache (valide/invalide) + test offline.

### S18 — Audio-follow (karaoké) + auto-scroll
- **Livrables** : timing mot/verset → surlignage + auto-scroll calé sur `scrollTempo` + amplitude.
- **Acceptation** : mot surligné suit l'audio ; ahead/sync/behind décalent visiblement ; amplitude réglable.
- **Vérif** : test mapping temps→mot + golden surlignage.

### S19 — Audio-mot (tap mot)
- **Livrables** : lecture du mot par position (source wbw) ; réglage `wordAudio`.
- **Acceptation** : tap mot joue **le bon** mot (mapping validé) ; off désactive.
- **Vérif** : test mapping position→fichier + recette manuelle.

### S20 — Audio bar (UI) + capture auto
- **Livrables** : barre flottante auto-hide (play, récitateur, vitesse, répétition, tempo, autoMaster) ; `autoMaster` marque maîtrisé en fin de verset.
- **Acceptation** : tous contrôles fonctionnels ; autoMaster on → fin de verset crée `masteredAt`.
- **Vérif** : widget tests barre + test autoMaster.

---

## P3 — Atlas & sélection

### S21 — Atlas Sourates (grille)
- **Livrables** : `features/atlas` grille 114 `HeatTile` ; `GetAtlasHeatUseCase`.
- **Acceptation** : tuiles colorées par chaleur dominante ; pastille fragile ; badge cicatrice.
- **Vérif** : golden Atlas (états variés via fake) + tests use case.

### S22 — Filtres & recherche
- **Livrables** : filtres Mecquoise/Médinoise/Mémorisée + recherche (nom/numéro/translit).
- **Acceptation** : filtres cumulables ; recherche insensible accents/casse.
- **Vérif** : tests filtrage/recherche.

### S23 — Vue Juz (et Hizb option)
- **Livrables** : grille 30 juz (+ hizb derrière réglage) avec chaleur agrégée.
- **Acceptation** : agrégation juz correcte ; navigation vers passage.
- **Vérif** : tests agrégation juz.

### S24 — Drill verset (heatmap fine)
- **Livrables** : ouverture d'une sourate → grille de versets `HeatCell`.
- **Acceptation** : couleur par verset exacte (parité `verseHeatState`) ; tap → Reader à l'ayah ; appui long → capture.
- **Vérif** : tests mapping état→couleur.

### S25 — Sélection passage → actions
- **Livrables** : depuis tuile/drill → « Lire » / « Ajouter à playlist » / « Réviser ».
- **Acceptation** : chaque action ouvre la bonne destination avec la bonne `Selection`.
- **Vérif** : tests navigation (go_router).

### S26 — Transition partagée Atlas→Reader
- **Livrables** : `Hero` (la tuile s'ouvre en page) ; respect Reduce motion.
- **Acceptation** : transition fluide, réversible ; désactivée si Reduce motion.
- **Vérif** : widget test présence/absence transition.

### S27 — Picker sourate (bottom sheet)
- **Livrables** : `LanternSheet` picker (sourate + plage ayah, sajda, mémorisée) réutilisable.
- **Acceptation** : choisir 2:255–2:257 produit `Surah(2,255,257)` ; sajda visible.
- **Vérif** : widget tests picker.

---

## P4 — Modèle fragile / maîtrise

### S28 — Port de l'algorithme (domain) + parité
- **Livrables** : `mastery.dart` (verseHeatState/verseFlag/decay/surahHeat) ; table de parité vs desktop ; horloge injectable.
- **Acceptation** : tous les cas de référence desktop passent à l'identique.
- **Vérif** : `dart test test/domain/mastery` (table de parité verte).

### S29 — Persistance état (data/mastery)
- **Livrables** : repos Fragile/Mastered/Memorized (Drift) + `Stream` réactifs.
- **Acceptation** : F/M/clear/reset persistent et réémettent ; concurrence sûre (transactions).
- **Vérif** : tests repo (Drift in-memory).

### S30 — Capture dans le Reader
- **Livrables** : appui long verset → `CaptureBar` (Fragile/Maîtrisé/Tafsir/Écouter) ; haptique + micro-anim braise.
- **Acceptation** : F → count+1 & markedAt ; M → masteredAt (count préservé) ; badge live.
- **Vérif** : widget test capture + assertion état.

### S31 — Cicatrice (badges)
- **Livrables** : `EmberBadge` cicatrice (maîtrisé + count>0) sur Reader + Atlas.
- **Acceptation** : un verset maîtrisé avec historique d'échecs montre la braise partout.
- **Vérif** : golden badges + test logique scarred.

### S32 — Decay & probation visibles
- **Livrables** : refroidissement appliqué à l'affichage Atlas/Reader ; probation count≥5.
- **Acceptation** : avance du temps (horloge injectée) fait évoluer fresh→fading→stale aux seuils du profil.
- **Vérif** : tests temps simulé (now injecté).

### S33 — File de décroissance (queue)
- **Livrables** : `GetDecayQueueUseCase` (tri catégorie fragile>stale>fading puis difficulté).
- **Acceptation** : ordre conforme ; scope global ou par sélection.
- **Vérif** : tests de tri.

---

## P5 — Programme du jour (SRS)

### S34 — Écran Programme (file en surface)
- **Livrables** : `features/program` liste « ce qui s'éteint » (`ProgramCard`).
- **Acceptation** : affiche la file triée ; vide → état doux (filigrane, micro-copy).
- **Vérif** : widget tests (liste/empty).

### S35 — Micro-session de révision
- **Livrables** : runner enchaînant N versets (écoute + voile) avec capture inline F/M.
- **Acceptation** : session de 5 versets se déroule, capture met à jour l'état, fin → résumé doux.
- **Vérif** : `integration_test` parcours complet.

### S36 — Bouton « 3 minutes » (calibrage)
- **Livrables** : session calibrée sur durée dispo (estimation par longueur/temps audio).
- **Acceptation** : « 3 min » sélectionne un nombre de versets cohérent.
- **Vérif** : test d'estimation durée.

### S37 — Streak doux
- **Livrables** : `ComputeStreakUseCase` (jours consécutifs avec ≥1 session) + affichage non culpabilisant.
- **Acceptation** : streak augmente/repart sans message agressif ; persistant.
- **Vérif** : tests streak (dates simulées).

### S38 — Stats zones chaudes
- **Livrables** : top sourates fragiles/à revoir, vue sobre (pas de gamification anxiogène).
- **Acceptation** : classement correct ; n'expose pas de « score religieux ».
- **Vérif** : tests agrégation.

### S39 — Cicatrices sur tuiles Atlas
- **Livrables** : braise au niveau tuile sourate/juz (pas seulement cellule).
- **Acceptation** : tuile d'une sourate contenant des cicatrices l'indique.
- **Vérif** : golden tuiles cicatrisées.

---

## P6 — Playlists

### S40 — CRUD playlists nommées
- **Livrables** : `features/playlists` (créer/renommer/supprimer) + repo Drift.
- **Acceptation** : playlists persistées, listées, éditables.
- **Vérif** : tests repo + widget.

### S41 — Composer (ajout items niveau ayah)
- **Livrables** : ajout d'un passage (via picker/Atlas) à une playlist ; label auto.
- **Acceptation** : item ajouté avec `Selection` correcte + label lisible.
- **Vérif** : tests composition.

### S42 — Réordonner (drag) + supprimer item
- **Livrables** : `ReorderableListView`, suppression, ordre persistant.
- **Acceptation** : ordre conservé après reload.
- **Vérif** : widget test drag + persistance.

### S43 — Auto-avance lecture playlist
- **Livrables** : enchaînement des passages (`activePlaylistId`), indicateur item courant, bouclage option.
- **Acceptation** : fin d'un passage → suivant ; boucle si activée ; indicateur correct.
- **Vérif** : tests auto-avance (matching sélection).

### S44 — Marqueur « mémorisée »
- **Livrables** : toggle sourate mémorisée (alimente filtre Atlas + défauts voile).
- **Acceptation** : marquer une sourate la filtre dans Atlas et ajuste comportements liés.
- **Vérif** : tests intégration filtre.

---

## P7 — Tafsir

### S45 — Données tafsir (offline)
- **Livrables** : pipeline tafsir → assets/table ; arbitrage embarqué vs téléchargé selon taille mesurée.
- **Acceptation** : tafsir d'une sourate accessible offline (après 1er téléchargement si non embarqué).
- **Vérif** : test lazy-load tafsir.

### S46 — Panneau Tafsir contextuel
- **Livrables** : `features/tafsir` panneau depuis un verset (FR/EN), typo parchemin, sans quitter le contexte.
- **Acceptation** : ouvrir tafsir, changer langue, fermer en gardant la position Reader.
- **Vérif** : widget test ouverture/fermeture.

### S47 — Langue & réglage tafsir
- **Livrables** : `tafsirLanguage`, état ouvert/fermé persistés.
- **Acceptation** : préférences respectées au retour.
- **Vérif** : tests réglages.

---

## P8 — Surfaces interstitielles (ré-incarnation de l'overlay)

### S48 — Deep links type-safe (go_router)
- **Livrables** : liens vers Program/Reader/verset/micro-session.
- **Acceptation** : chaque lien ouvre la bonne destination/état (cold & warm start).
- **Vérif** : tests deep link (`integration_test`).

### S49 — Notifications (canaux + média)
- **Livrables** : canal « Révision » + contrôles média via `audio_service` ; permission Android 13+ / iOS.
- **Acceptation** : contrôles média pilotent la lecture ; permission gérée proprement.
- **Vérif** : recette notifs documentée + test config.

### S50 — Rappel de révision programmable
- **Livrables** : `reminders` (heure/fréquence) via `workmanager` (Android) / `flutter_local_notifications` scheduling (iOS) ; actions « Réviser 3 min »/« Plus tard ».
- **Acceptation** : notification arrive à l'heure choisie ; action ouvre micro-session.
- **Vérif** : test scheduling (mock) + recette appareil.

### S51 — Home widget Android 2×2
- **Livrables** : `home_widget` + RemoteViews/Glance « verset à revoir du jour » + CTA ; MAJ via `workmanager`.
- **Acceptation** : widget affiche le bon verset ; tap → micro-session.
- **Vérif** : recette visuelle + test data du widget.

### S52 — Home widget Android 4×2 + Widget iOS WidgetKit
- **Livrables** : variante riche Android (streak + 2–3 versets) ; extension WidgetKit iOS (small/medium) via `home_widget`.
- **Acceptation** : rendu correct des deux côtés ; MAJ après session.
- **Vérif** : golden/recette par plateforme.

### S53 — Quick Settings Tile (Android) / App Shortcuts (iOS)
- **Livrables** : `TileService` natif « Réviser maintenant » ; App Intents/Siri côté iOS.
- **Acceptation** : déclenche la micro-session.
- **Vérif** : recette par plateforme.

### S54 — Bulle Android (Bubble API, opt-in)
- **Livrables** : pastille flottante « réviser » par-dessus les autres apps, activité compacte (Android only).
- **Acceptation** : opt-in explicite ; ouvre une mini-révision ; jamais activée par défaut.
- **Vérif** : recette bulle + garde opt-in testée.

### S55 — Reprise & cohérence d'état
- **Livrables** : toutes surfaces convergent vers le même état (verset courant, file).
- **Acceptation** : réviser depuis widget/notif/tuile met à jour l'app et inversement.
- **Vérif** : tests d'intégration état partagé.

---

## P9 — Réglages & thèmes

### S56 — Écran Réglages (sections)
- **Livrables** : `features/settings` (Récitation/Lecture/Révision/Apparence/Données/À propos).
- **Acceptation** : tous réglages des phases précédentes pilotables ici.
- **Vérif** : widget tests par section.

### S57 — Thèmes Lanterne/Rawda/Parchemin/Contraste
- **Livrables** : 4 thèmes en `ThemeExtension` ; transition douce.
- **Acceptation** : changement instantané, cohérent partout, contraste AA/AAA (contraste élevé).
- **Vérif** : golden par thème (écrans clés).

### S58 — Dynamic color (Android 12+, bridé)
- **Livrables** : `dynamicColor` opt-in (`dynamic_color`), dérivé du fond d'écran, **contraint** sur rampe sombre lanterne.
- **Acceptation** : activé → accent dérivé sans casser la lisibilité ; off → lanterne fixe ; iOS ignore proprement.
- **Vérif** : golden dynamic on/off.

### S59 — Données : download manager + espace
- **Livrables** : UI passage/sourate/juz/Coran par récitateur, espace utilisé, purge sélective, reprise.
- **Acceptation** : télécharger une sourate la rend offline ; purge mesurable.
- **Vérif** : tests intégration cache + widget.

### S60 — Export/import état de révision
- **Livrables** : export JSON local (`share_plus`/file) + import (merge non destructif).
- **Acceptation** : export→import sur appareil neuf restaure fragile/maîtrise/playlists/réglages.
- **Vérif** : test round-trip export/import.

---

## P10 — Design polish, motion & accessibilité

### S61 — Onboarding léger (coachmark)
- **Livrables** : `features/onboarding` 1er lancement (pas de wizard) ; `coachmarkSeen`.
- **Acceptation** : montré une fois, passable, jamais bloquant.
- **Vérif** : widget test 1er/2e lancement.

### S62 — États vides & filigranes
- **Livrables** : basmala stylisée + micro-copy douce sur chaque écran vide.
- **Acceptation** : aucun écran vide « brut ».
- **Vérif** : golden empty states.

### S63 — Motion expressif + décor vivant
- **Livrables** : easing/durations en tokens ; micro-anim braise ; transitions affinées ; **décor lanterne** (horizon + feuilles d'or par ayah, fragment shader pour le glow) porté du desktop, opt-in.
- **Acceptation** : cohérence motion ; décor fluide 60fps ; Reduce motion respecté partout.
- **Vérif** : widget tests reduce-motion + recette perf décor.

### S64 — Haptique
- **Livrables** : retours haptiques (capture, fin de session, toggles importants).
- **Acceptation** : haptique pertinente, désactivable.
- **Vérif** : recette + réglage off.

### S65 — Accessibilité complète
- **Livrables** : audit lecteur d'écran (TalkBack/VoiceOver), ordre de focus, descriptions, scaling police, contrastes.
- **Acceptation** : parcours principaux navigables au lecteur d'écran ; police XXL non cassante.
- **Vérif** : tests sémantiques + checklist a11y.

### S66 — Adaptatif (tablette/foldable/landscape)
- **Livrables** : layouts adaptatifs (Reader 2 colonnes sur large, Atlas dense) via `LayoutBuilder`.
- **Acceptation** : pas de casse en large/landscape/foldable.
- **Vérif** : golden multi-tailles.

---

## P11 — Offline complet & performance

### S67 — Init offline 1er lancement
- **Livrables** : copie/ouverture `corpus.db` ; tafsir/police vérifiés ; récitateur par défaut minimal éventuel.
- **Acceptation** : app pleinement utilisable hors-ligne juste après install.
- **Vérif** : test mode avion après install.

### S68 — Perf : profil & budgets
- **Livrables** : profiling (`flutter run --profile`, DevTools timeline) scroll Reader / ouverture Atlas / cold start ; budgets taille app.
- **Acceptation** : cold start rapide ; scroll 60 fps+ (Impeller, zéro jank visible).
- **Vérif** : trace timeline archivée + assertion budget.

### S69 — Cache de mesure arabe
- **Livrables** : cache (texte,largeur)→layout ; éviter recompute au scroll.
- **Acceptation** : pas de recompute mesure au scroll ; mémoire stable.
- **Vérif** : trace DevTools + test cache.

### S70 — Robustesse réseau/erreurs
- **Livrables** : gestion offline/erreurs audio (retry/backoff, messages doux), pas de crash.
- **Acceptation** : coupure réseau en pleine lecture → reprise propre depuis cache.
- **Vérif** : tests d'injection d'erreurs.

### S71 — Stabilité & fuites
- **Livrables** : revue dispose/lifecycles (controllers, handler audio, widgets) ; chasse aux leaks (DevTools memory).
- **Acceptation** : zéro fuite sur parcours clés.
- **Vérif** : run mémoire documenté.

---

## P12 — Sync / compte Pro (optionnel)

### S72 — Abstraction sync + gating Pro
- **Livrables** : interface `SyncService` + flag Pro ; **no-op** par défaut.
- **Acceptation** : app fonctionne sans compte ; surface Pro non bloquante.
- **Vérif** : tests gating.

### S73 — Backup chiffré local/cloud
- **Livrables** : backup chiffré (clé dérivée) export vers stockage choisi.
- **Acceptation** : backup/restore chiffré round-trip.
- **Vérif** : test crypto round-trip.

### S74 — Sync multi-appareils (E2E)
- **Livrables** : sync état de révision chiffré de bout en bout (provider au choix).
- **Acceptation** : 2 appareils convergent sans exposer la donnée en clair.
- **Vérif** : test sync simulé (2 stores).

### S75 — Récitateurs Pro offline
- **Livrables** : déblocage récitateurs additionnels offline.
- **Acceptation** : achat/licence débloque ; gracieux si non-Pro.
- **Vérif** : tests gating + cache.

### S76 — Facturation (`in_app_purchase`)
- **Livrables** : abo léger + licence à vie ; restauration d'achat (Play + App Store).
- **Acceptation** : flux d'achat/restore testé en sandbox des deux stores.
- **Vérif** : recette sandbox IAP.

---

## P13 — Release stores

### S77 — Build release signé (Android + iOS)
- **Livrables** : signing Android (keystore sécurisé) + iOS (certs/profiles) ; shrink/obfuscation Dart (`--obfuscate --split-debug-info`).
- **Acceptation** : `flutter build appbundle` et `flutter build ipa` OK, app release sans crash.
- **Vérif** : smoke test release sur appareil réel.

### S78 — Privacy & permissions audit
- **Livrables** : Data Safety (Play) + Privacy Manifest/Nutrition Labels (App Store) ; justification permissions ; politique de confidentialité.
- **Acceptation** : permissions minimales justifiées ; pas de tracking.
- **Vérif** : revue checklists Play + App Store.

### S79 — Store listings & assets
- **Livrables** : descriptions FR/EN, captures, vidéo, icônes adaptatives (Android) + app icon iOS, feature graphic.
- **Acceptation** : listings complets conformes (les deux stores).
- **Vérif** : pré-revue interne.

### S80 — Pistes de test internes
- **Livrables** : AAB sur piste interne Play + TestFlight interne iOS ; testeurs, retours.
- **Acceptation** : install via store (interne) OK sur ≥3 appareils (mix Android/iOS).
- **Vérif** : rapport de test interne.

### S81 — Beta (closed/open + TestFlight)
- **Livrables** : beta + collecte feedback + monitoring crash (Crashlytics/Sentry au choix, opt-in).
- **Acceptation** : crash-free sessions > 99 % sur beta.
- **Vérif** : tableau de bord stabilité.

### S82 — Production rollout
- **Livrables** : rollout progressif Play (10→50→100 %) + soumission App Store ; notes de version.
- **Acceptation** : pas de pic de crash ; métriques stables.
- **Vérif** : suivi post-release documenté.

---

## Backlog différé / idées (non planifiées)
- Mode « vocal » expérimental (auto-évaluation à voix haute) — opt-in, hors chemin critique.
- Wear OS / watchOS compagnon (révision au poignet).
- Multi-traductions/multi-tafsirs téléchargeables.
- Partage d'un verset en image (carte lanterne) — opt-in, sans réseau social.
- Statistiques avancées Pro (courbes de rétention par zone).

## Suivi
- Cocher chaque `Sx` à la clôture (ou un `PROGRESS.md`).
- Tout écart de périmètre validé → noté dans `DECISIONS.md`.
