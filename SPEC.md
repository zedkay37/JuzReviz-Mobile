# JuzReviz Mobile — Spécification produit, design & features

## 1. Vision

> **« Le Coran qui vit dans ta journée. »**

Cible principale : le **professionnel qui a mémorisé du Coran et le perd** (hafiz
partiel). Il n'a pas 1 h de muraja'a par jour ; il a **dix fois trois minutes**.
L'app transforme ces interstices en révision réelle, sans culpabilité, sans
dashboard, sans friction.

Cible secondaire : le **débutant** (écoute + suivi mot-à-mot interlinéaire), et le
**lecteur** qui veut un mushaf interlinéaire premium hors-ligne.

Trois promesses :
1. **Lire est sublime** — typographie arabe monumentale, interlinéaire propre, lanterne.
2. **Réviser est invisible** — le SRS se présente comme un programme du jour qui vient à toi (widget, notif), jamais comme un examen.
3. **Rien ne se perd** — la difficulté historique d'un verset survit à la maîtrise (cicatrice) ; on ne baisse jamais la garde sur une zone dure.

### Anti-vision (ce que l'app n'est pas)
- Pas un dashboard de stats gamifié anxiogène.
- Pas un réseau social, pas de feed, pas de pub.
- Pas un mushaf figé image : c'est du **texte vivant** (sélection, audio, gloses, tafsir).
- Pas un tuteur qui juge le niveau religieux.

## 2. Design system « Lanterne » (premium, minimaliste, smart)

### 2.1 Principes
- **Profondeur & calme** : fond très sombre par défaut, surfaces en élévations subtiles, **un seul accent chaud** (braise/ambre) qui guide l'œil.
- **Le texte est le héros** : l'arabe domine ; l'UI s'efface (chrome auto-hide, immersif).
- **Une intention par écran** : chaque vue se reconnaît d'un coup d'œil.
- **Jamais d'état vide brut** : filigrane (basmala stylisée), micro-copy douce.
- **Material 3 (Flutter)** côté Android, **Cupertino-aware** côté iOS (respect des conventions natives : retour gestuel, feuilles, haptique), mais **discipliné par la lanterne** — pas de couleurs criardes par défaut.

### 2.2 Thèmes
| Thème | Usage | Note |
|---|---|---|
| **Lanterne (nuit)** | défaut | fond `#0B0B0D`, accent ambre `#E8B765`, texte `#F4ECDD` |
| **Rawda (jardin)** | jour doux | vert profond, accent or |
| **Parchemin** | lecture longue diurne | sépia clair, encre brune |
| **Contraste élevé** | a11y | AAA, noir/blanc + accent unique |
| **Dynamic (Material You)** | opt-in Android 12+ | dérive l'accent du fond d'écran, **bridé** sur une rampe sombre |

- Dark par défaut ; suit le réglage système si l'utilisateur choisit « Auto ».
- Couleur encodée en **tokens** (`ThemeExtension` Flutter), jamais en dur.

### 2.3 Typographie
- **Arabe** : police mushaf de qualité (Uthmanic Hafs / KFGQPC) embarquée. Taille **fluide** selon largeur ; **jamais de coupe de mot ni de harakat**. Line-height généreux.
- **Latin** : une famille variable lisible (ex. Inter) pour gloses, traduction, UI. Translittération en italique discrète.
- Échelle typographique en tokens (display arabe / verse / gloss / ui-title / ui-body / caption).

### 2.4 Motion & haptique
- **Transitions partagées** (`Hero`) Atlas→Lecteur (la tuile s'ouvre en page).
- **Capture fragile/maîtrisé** : micro-animation braise + **haptique** (`HapticFeedback`).
- **Audio-follow** : surlignage mot-à-mot fluide (karaoké), easing doux.
- **Décor vivant** (repris du desktop) : feuilles d'or à chaque ayah + horizon de croissance — opt-in, jamais imposé.
- Respecter `MediaQuery.disableAnimations` / Reduce motion système → désactive les transitions non essentielles.

### 2.5 Composants signature (designsystem)
- `LanternScaffold` — scaffold edge-to-edge, immersif auto-hide, gestion des `SafeArea`/insets.
- `ArabicVerse` — rendu d'un verset (RTL, tajwid optionnel, mots tappables, surlignage audio).
- `InterlinearVerse` — verset + gloses mot-à-mot + traduction (le flagship).
- `HeatCell` / `HeatTile` — cellule/tuile de chaleur (couleur dominante + pastille fragile + cicatrice).
- `EmberBadge` — badge d'état (fragile/maîtrisé/cicatrice).
- `CaptureBar` — barre de capture rapide (Fragile / Maîtrisé) contextuelle.
- `LanternSheet` — bottom sheet thémé lanterne.
- `ProgramCard` — carte « programme du jour ».

## 3. Architecture de l'information (vues)

### 3.1 Navigation racine (bottom nav, 4 destinations max — épure)
1. **Lire** (Reader) — la maison ; reprend où on s'est arrêté.
2. **Programme** (révision du jour + capture) — le cœur SRS.
3. **Atlas** (heatmap d'ensemble + sélection) — naviguer/choisir.
4. **Playlists** — passages enregistrés.

> Réglages = icône en haut (pas une destination), Tafsir = panneau contextuel,
> Recherche = action dans Atlas.

### 3.2 Écrans détaillés

#### A. Reader (flagship)
- **Interlinéaire scroll multi-versets** : chaque verset = arabe monumental, sous chaque mot sa **glose** (FR/EN, langue réglable), et sous le verset la **traduction** (FR/EN). Toggles indépendants Mot-à-mot / Traduction.
- **Sceau d'ayah** (numéro stylisé, chiffres arabes ou latins selon réglage).
- **Audio bar** flottante auto-hide : play/pause, récitateur, vitesse, répétition, tempo de défilement (ahead/sync/behind + amplitude), mode « capture auto » (autoMaster).
- **Audio-follow** : surligne le mot/verset courant ; auto-scroll calé selon `scrollTempo`.
- **Geste capture** : appui long sur un verset → `CaptureBar` (Fragile / Maîtrisé / Tafsir / Écouter). Swipe court = raccourci configurable.
- **Tap mot** : joue l'audio du mot (si `wordAudio`).
- **Focus mode** : masque tout sauf le texte (immersif total) — remplace le « minimalist » desktop.
- **Voile** (pratique) : `full` / `firstWords(n)` / `hidden` pour s'auto-tester (texte masqué, révélation au tap).

#### B. Programme (révision du jour) — surface phare
- **File « Ce qui s'éteint »** : versets triés par urgence (fragile > stale > fading), pilotée par l'algo de decay.
- **Micro-session** : enchaîne N versets en mode révision (écoute + voile), capture inline (geste F = +1 difficulté, geste M = maîtrisé).
- **Streak doux** : jours consécutifs avec au moins une micro-session (motivant, non culpabilisant).
- **Statistiques zones chaudes** : top sourates fragiles, sans gamification anxiogène.
- **Bouton « 3 minutes »** : lance une session courte calibrée sur le temps dispo.

#### C. Atlas (heatmap + sélection)
- **Vue Sourates** (114 tuiles) : couleur = chaleur dominante, pastille = fragile présent, badge cicatrice. Filtres : Mecquoises/Médinoises/**Mémorisées**, recherche (nom/numéro/translit).
- **Vue Juz** (30) et **Vue Hizb** (option).
- **Drill verset** : ouvrir une sourate → grille de versets (heatmap fine), tap → ouvre le Reader à l'ayah, appui long → capture.
- **Sélection passage** : depuis une tuile ou un drill → « Lire » / « Ajouter à playlist » / « Réviser ».

#### D. Playlists
- Liste de playlists **nommées** ; chaque item = passage (sourate+plage, juz, ou liste de versets « review »).
- Composer au niveau ayah, réordonner (drag), marqueur sajda dans le picker.
- **Auto-avance** : lire une playlist enchaîne les passages ; indicateur d'item courant ; bouclage option.
- Marqueur **« mémorisée »** par sourate (alimente filtre Atlas + masque le voile par défaut, etc.).

#### E. Tafsir (panneau contextuel)
- Ouvert depuis un verset ; tafsir par sourate (FR/EN), lazy-load offline.
- Lecture confortable (typo parchemin), pas de quitter le contexte.

#### F. Réglages (sections)
- **Récitation** : récitateur, vitesse, répétition (ayah/range/progressif + count + pause), tempo de défilement + amplitude, audio-mot, capture auto.
- **Lecture & affichage** : mot-à-mot on/off + langue, traduction on/off + langue, tajwid, chiffres latins, voile + nb de mots, focus mode.
- **Révision** : profil de maîtrise (Sérénité/Excellence), rappels (heure, fréquence), surfaces interstitielles (widget/notif/tuile).
- **Apparence** : thème, taille de police, dynamic color (Android), décor vivant, garder l'écran allumé.
- **Données** : gestionnaire de téléchargement (passage/sourate/juz/Coran), espace utilisé, purge, export/import de l'état de révision.
- **À propos** : sources & attributions (CC BY-NC), licences polices, vie privée.

### 3.3 Surfaces interstitielles (la ré-incarnation de l'overlay) — par plateforme

**Android**
- **Home widget (Glance/XML via `home_widget`)** : « verset fragile/à revoir du jour » + bouton « Réviser » ; tailles 2×2 et 4×2 ; tap ouvre une micro-session directe.
- **Notification de révision** : rappel programmable ; actions inline « Réviser 3 min » / « Plus tard » ; style média pendant la lecture (play/pause/seek, casque, lockscreen).
- **Quick Settings Tile** : « JuzReviz — Réviser maintenant ».
- **Bulle (Bubble API, opt-in)** : pastille flottante par-dessus les autres apps (traduction la plus fidèle de l'overlay desktop ; toujours opt-in).

**iOS**
- **Widget WidgetKit** (small/medium) : verset du jour + deep link micro-session.
- **Live Activity / Dynamic Island** (option) pendant une session/lecture.
- **App Shortcuts / Siri** : « Réviser maintenant ».
- **Notifications** programmables + contrôles média (lockscreen). Pas d'équivalent « bulle » (limite système).

- **Reprise** : toutes ces surfaces ouvrent directement le Programme/Reader au bon verset (deep links go_router).

## 4. Spécifications fonctionnelles détaillées

### 4.1 Modèle fragile / maîtrise (cœur)
Repris du desktop, **inchangé sémantiquement** (code Dart dans `ARCHITECTURE.md §5`). Règles produit :
- 3 faits par verset, **jamais écrasés** : `markedAt` (dernier échec), `count` (difficulté cumulée), `masteredAt` (dernière maîtrise).
- État affiché = **récence** entre dernier échec et dernière maîtrise (le plus récent gagne).
- Geste **F** → `count+1`, `markedAt=now`. Geste **M** (ou capture auto en fin de verset) → `masteredAt=now` (préserve `count`). **Retrait** → purge la difficulté. Reset total → via drill heatmap (confirmation).
- **Cicatrice** : maîtrisé mais `count>0` → braise sur la feuille verte (badges Reader + cellules Atlas + tuiles).
- **Decay accéléré** par difficulté (facteur `1+count·0.15`, plafond ×2.5) + **probation** (`count≥5` → fenêtre fraîche bornée 3 j Excellence / 7 j Sérénité).
- Profils : **Sérénité** (frais<180 j, à rafraîchir<365 j) / **Excellence** (frais<30 j, à rafraîchir<90 j).

### 4.2 Audio
- Streaming + **cache offline** par verset (récitateur sélectionné) ; allowlist stricte de sources (everyayah, audio.qurancdn.com/wbw). Validation des fichiers (magic bytes mp3).
- **Audio-mot** : par index de mot (segment timing) ; tap mot = lecture du mot.
- **Audio-follow** (karaoké) : timing mot/verset → surlignage + auto-scroll selon tempo.
- Répétition : par ayah, par passage (range), **progressif** (∞ interdit en progressif) ; pause inter-répétitions réglable ; vitesse 0.5–2×.
- Lecture **arrière-plan** (`audio_service`) : casque, lockscreen, notif média, CarPlay/Android Auto-ready.

### 4.3 Sélection & passages
- Modèle de sélection : `Juz(n)`, `Surah(n, from, to)`, `Review(label, verseKeys[])`.
- Picker sourate avec filtres (Mecquoise/Médinoise/Mémorisée) + recherche + sajda.

### 4.4 Voile (auto-test)
- `full` (tout visible), `firstWords(n)` (n premiers mots, reste masqué, révélation progressive au tap), `hidden` (révélation verset par verset).

### 4.5 Téléchargements / offline
- Granularité : passage / sourate / juz / Coran entier (par récitateur).
- Indicateur d'espace, purge sélective, reprise de téléchargement.
- Texte + gloses + traduction + tafsir **toujours disponibles** offline (embarqués ou pré-téléchargés au premier lancement).

### 4.6 Sauvegarde / portabilité (vie privée)
- État de révision (fragile/maîtrise/playlists/réglages) **exportable** en JSON local et **importable**.
- **Sync Pro (optionnel, phase tardive)** : backup chiffré ou sync E2E ; jamais requis pour l'usage de base.

## 5. Modèle économique (cadre, non bloquant pour le dev)
- **Gratuit** : lecture, interlinéaire, révision, fragile/maîtrise, 1–2 récitateurs offline, widget/notif.
- **Pro** (abo léger ou licence à vie) : tous récitateurs offline, sync multi-appareils, thèmes premium, stats avancées.
- Pas de pub, pas de revente de données. Le free reste pleinement utile (pas de dark pattern).

## 6. Métriques de succès produit (privées, locales)
- Régularité (jours avec micro-session) plutôt que volume.
- Réduction du nombre de versets « stale/fragile » dans les zones marquées « mémorisées ».
- Temps-jusqu'à-première-révision après ouverture (doit être < 5 s via Programme/widget).

> Ces métriques guident le design ; elles ne sont pas un dashboard imposé à l'utilisateur.
