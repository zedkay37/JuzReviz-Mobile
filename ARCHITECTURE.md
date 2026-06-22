# JuzReviz Mobile (Flutter) — Architecture technique

## 1. Stack & conventions

| Domaine | Choix |
|---|---|
| Framework | Flutter (stable, moteur Impeller) |
| Langage | Dart 3, sound null-safety |
| Architecture | Clean / feature-first, UDF |
| State / DI | Riverpod (`riverpod_generator`, `riverpod_annotation`) |
| Navigation | go_router (type-safe + deep links) |
| Persistance | Drift (SQLite) — corpus prépeuplé (read-only) + tables d'état mutables |
| Réglages | JSON via `path_provider`, sanitize au chargement (modèle `Settings` immuable, `freezed`) |
| Audio | just_audio + audio_service (`BaseAudioHandler`) |
| i18n | `flutter_localizations` + ARB (FR/EN) |
| Modèles | `freezed` + `json_serializable` (domaine pur) |
| Widgets natifs | `home_widget` + code natif (Android Glance/RemoteViews, iOS WidgetKit) |
| Tests | `flutter_test`, `golden_toolkit`, `integration_test`, `mocktail` |
| Qualité | `very_good_analysis`, `dart format`, `flutter analyze` |
| CI | GitHub Actions (analyze + test + build apk/ipa) |

Cibles : Android `minSdkVersion 24` / iOS 14+. **Offline-first** strict (zéro réseau au démarrage).

## 2. Structure du projet (feature-first, couches respectées)

```
lib/
  main.dart                      # bootstrap, ProviderScope, thème racine, go_router
  core/
    common/                      # Result, extensions, constantes, clock injectable
    designsystem/                # tokens (ThemeExtension), thèmes, composants Lanterne, motion
    arabic/                      # ArabicText (RTL, non-coupure), métrique mise en cache
    routing/                     # go_router + deep links type-safe
  data/
    db/                          # Drift : tables corpus (read-only) + état, DAO, migrations
    corpus/                      # CorpusRepository (lecture versets/mots/métas)
    audio/                       # téléchargement, cache offline, allowlist, AudioHandler
    mastery/                     # repos Fragile/Mastered/Memorized/Playlists (Drift)
    settings/                    # SettingsRepository (JSON + sanitize), modèle Settings
  domain/                        # PUR (aucun import Flutter) : modèles + use cases + mastery.dart
    model/                       # Verse, Word, SurahMeta, Selection, enums
    mastery/                     # mastery.dart (algo, testable Dart pur)
    usecase/                     # GetReaderVerses, GetDecayQueue, GetAtlasHeat, GetTodayProgram…
  features/
    reader/                      # lecteur interlinéaire + audio bar  (UI + controllers Riverpod)
    program/                     # programme du jour / révision SRS
    atlas/                       # heatmap + sélection + picker
    playlists/                   # playlists CRUD + auto-avance
    tafsir/                      # panneau tafsir
    settings/                    # réglages
    onboarding/                  # premier lancement (coachmark léger)
android/  ios/                   # plateformes + widgets natifs (Glance / WidgetKit) + tiles
tools/                          # scripts de build du corpus (Dart ou Node)
assets/
  corpus/corpus.db               # base Drift prépeuplée (générée)
  tafsir/{fr,en}/{n}.json        # tafsir lazy (ou table dédiée)
  fonts/                         # police mushaf + licences
test/  integration_test/        # unit, golden, e2e
```

Règles de dépendances : `features/*` → `domain` → `data/*` → `core/*`. **Aucune**
dépendance inverse, **aucun** `feature` → `feature`. Le dossier `domain/`
**n'importe pas Flutter** (testable en `dart test` pur). Option monorepo `melos`
si on veut des packages stricts ; non requis au départ.

## 3. Couche données

### 3.1 Corpus (texte, gloses, traduction) — Drift read-only
- Source de vérité = base **Drift prépeuplée** `assets/corpus/corpus.db`, ouverte via
  `NativeDatabase` après copie de l'asset au premier lancement (helper
  `drift_dev` / `createFromAsset`-like). Le corpus est **read-only** à l'exécution.

```dart
// domain/model — freezed
@freezed
class Verse with _$Verse {
  const factory Verse({
    required int surah,
    required int ayah,
    required String verseKey,   // "2:255"
    required int juz,
    required String arabic,     // texte uthmani (avec harakat)
    required String translationFr,
    required String translationEn,
  }) = _Verse;
}

@freezed
class Word with _$Word {
  const factory Word({
    required String verseKey,
    required int position,      // 1-based, aligné sur l'audio-mot
    required String arabic,
    required String glossFr,
    required String glossEn,
    required String translit,
    required bool isWaqf,       // signe de pause (rendu plus petit)
  }) = _Word;
}

@freezed
class SurahMeta with _$SurahMeta {
  const factory SurahMeta({
    required int number,
    required int ayahCount,
    required String arabicName,
    required String transliteration,
    required String englishName,
    required Revelation revelation, // meccan | medinan
    required bool hasSajda,
    required int juzStart,
  }) = _SurahMeta;
}
```

### 3.2 État de révision (Drift, lecture/écriture)
Tables : `fragile(verseKey PK, markedAtMs, count)`,
`mastered(verseKey PK, masteredAtMs)`,
`playlist(id PK, name, order)`,
`playlist_item(id PK, playlistId, order, selectionJson, label)`,
`memorized_surah(surah PK)`,
`audio_cache(key PK, reciter, verseKey, path, bytes)`.
DAO exposant des `Stream` (réactif) ; mutations transactionnelles.

### 3.3 Réglages (JSON + sanitize)
Modèle `Settings` (`freezed`, immuable) reprenant `ShellSettings` desktop, adapté
mobile (mapping §4). `SettingsRepository` :
- charge le JSON (path_provider) → `Settings.fromJsonSanitized(raw)` : **toute clé
  absente reçoit un défaut** (équivalent strict de la sanitisation desktop) ;
- expose un `Stream<Settings>` (Riverpod) ; persiste en debounce.

### 3.4 Sélection (sérialisée pour playlists/reprise)
```dart
@freezed
sealed class Selection with _$Selection {
  const factory Selection.juz(int juz) = SelJuz;
  const factory Selection.surah(int surah, int from, int to) = SelSurah;
  const factory Selection.review(String label, List<String> verseKeys) = SelReview;
  factory Selection.fromJson(Map<String, dynamic> j) => _$SelectionFromJson(j);
}
```

## 4. Mapping des réglages desktop → mobile

| Desktop (`ShellSettings`) | Mobile | Décision |
|---|---|---|
| reciter, playbackRate, repeat, practice | identiques | gardés |
| readerWordByWord, glossLang, readerTranslation, translationLang | identiques | gardés |
| tajweedColors, latinAyahNumbers, wordAudio | identiques | gardés |
| scrollTempo, scrollTempoStrength | identiques | gardés (audio-follow) |
| tafsirOpen, tafsirLanguage | identiques | gardés |
| theme, opacity | theme gardé ; **opacity supprimé** | pas de fenêtre transparente |
| calmChrome | → **immersiveAutoHide** | idiome mobile |
| alwaysOnTop, locked | **supprimés** | non pertinents |
| displayMode minimalist/normal, minimalFocusMode | **fusionnés** → `focusMode: bool` | un seul lecteur adaptatif |
| fragileVerses, masteredVerses, masteryProfile, autoMaster | identiques (en Drift) | cœur conservé |
| playlists, activePlaylistId, memorizedSurahs, currentVerseKey | identiques | gardés |
| ambientDecor, decorMinutes, decorDate, ayahsToday, lettersToday | **repris** | décor vivant + compteur d'effort |
| — (nouveau) | `reminders` (enabled/time/frequency), `widgetEnabled`, `dynamicColor`, `keepScreenOn` | surfaces mobiles |

## 5. Maîtrise — algorithme porté en Dart (IP, à reproduire fidèlement)

`domain/mastery/mastery.dart` (pur, testable `dart test`). **Aucune donnée dérivée stockée.**

```dart
enum MasteryProfile { serenity, excellence }
enum HeatState { fragile, fresh, fading, stale, blank }

class _Thresholds {
  const _Thresholds(this.freshDays, this.fadingDays);
  final double freshDays;
  final double fadingDays;
}

_Thresholds _thresholds(MasteryProfile p) => switch (p) {
      MasteryProfile.serenity => const _Thresholds(180, 365),
      MasteryProfile.excellence => const _Thresholds(30, 90),
    };

const double _dayMs = 86400000.0;

double daysSince(int epochMs, int now) =>
    epochMs <= 0 ? double.infinity : math.max(0.0, (now - epochMs) / _dayMs);

/// Decay accéléré par difficulté + probation (count >= 5).
HeatState _decayState(int masteredAtMs, MasteryProfile p, int now, int failureCount) {
  final base = _thresholds(p);
  final factor = math.min(2.5, 1 + failureCount * 0.15);
  var fresh = base.freshDays / factor;
  final fading = base.fadingDays / factor;
  if (failureCount >= 5) {
    fresh = math.min(fresh, p == MasteryProfile.excellence ? 3.0 : 7.0);
  }
  final age = daysSince(masteredAtMs, now);
  if (age < fresh) return HeatState.fresh;
  if (age < fading) return HeatState.fading;
  return HeatState.stale;
}

class Fragile {
  const Fragile(this.markedAtMs, this.count);
  final int markedAtMs;
  final int count;
}

class Mastered {
  const Mastered(this.masteredAtMs);
  final int masteredAtMs;
}

/// État par RÉCENCE : le plus récent entre dernier échec et dernière maîtrise gagne.
HeatState verseHeatState(
    Fragile? fragile, Mastered? mastered, MasteryProfile profile, int now) {
  if (fragile == null && mastered == null) return HeatState.blank;
  if (fragile != null && mastered == null) return HeatState.fragile;
  final count = fragile?.count ?? 0;
  if (mastered != null && fragile == null) {
    return _decayState(mastered.masteredAtMs, profile, now, count);
  }
  return fragile!.markedAtMs > mastered!.masteredAtMs
      ? HeatState.fragile
      : _decayState(mastered.masteredAtMs, profile, now, count);
}

enum FlagState { fragile, mastered, blank }

class VerseFlag {
  const VerseFlag(this.state, this.scarred, this.failureCount);
  final FlagState state;
  final bool scarred;
  final int failureCount;
}

VerseFlag verseFlag(Fragile? fragile, Mastered? mastered) {
  final count = fragile?.count ?? 0;
  if (fragile == null && mastered == null) {
    return const VerseFlag(FlagState.blank, false, 0);
  }
  final FlagState state;
  if (fragile != null && mastered == null) {
    state = FlagState.fragile;
  } else if (mastered != null && fragile == null) {
    state = FlagState.mastered;
  } else if (fragile!.markedAtMs > mastered!.masteredAtMs) {
    state = FlagState.fragile;
  } else {
    state = FlagState.mastered;
  }
  return VerseFlag(state, state == FlagState.mastered && count > 0, count);
}

// Agrégat sourate (Atlas) : warmth 0..1, hasFragile, needsReview, dominant.
const _urgency = {
  HeatState.fragile: 4, HeatState.stale: 3, HeatState.fading: 2,
  HeatState.fresh: 1, HeatState.blank: 0,
};
const _weight = {
  HeatState.fresh: 1.0, HeatState.fading: 0.6, HeatState.stale: 0.25,
  HeatState.fragile: 0.0, HeatState.blank: 0.0,
};

class SurahHeat {
  const SurahHeat(this.warmth, this.hasFragile, this.needsReview, this.total, this.dominant);
  final double warmth;
  final bool hasFragile;
  final int needsReview;
  final int total;
  final HeatState dominant;
}
```

> **Parité obligatoire** : un test de table compare cette implémentation aux cas de
> référence du desktop (`JuzReviz2/src/core/mastery.ts`). Si un côté change, l'autre suit.
> L'horloge (`now`) est **injectable** (pas de `DateTime.now()` en dur) pour tester le decay.

### 5.1 Use cases (domain)
- `GetReaderVersesUseCase(selection)` → `Stream<List<InterlinearVerse>>` (corpus + flags).
- `MarkFragileUseCase` / `MarkMasteredUseCase` / `ClearDifficultyUseCase` / `ResetVerseUseCase`.
- `GetDecayQueueUseCase(profile, scope)` → file « ce qui s'éteint » (tri catégorie puis difficulté).
- `GetAtlasHeatUseCase(view)` → tuiles avec `SurahHeat`.
- `GetTodayProgramUseCase` → micro-session du jour (taille calibrable).
- `ComputeStreakUseCase` → jours consécutifs.

## 6. Pipeline data (réutiliser l'existant desktop)

Source : `JuzReviz2/public/data/words/{1..114}.json` (6236 versets : `w[]` avec
`ar/en/fr/tr`, + `en`/`fr` verset) et `public/tafsir/{fr,en}/{n}.json`.

Script `tools/build_corpus` (Dart via package `sqlite3`, **ou** Node réutilisé) :
1. Lit les 114 JSON words + métadonnées sourates + mapping juz.
2. Normalise → génère **`corpus.db`** (tables `verse`, `word`, `surah_meta` + index `verseKey`/`surah`/`juz`), schéma compatible Drift.
3. Compacte les tafsirs en assets `tafsir/{fr,en}/{n}.json` (lazy-load) ou table dédiée.
4. Émet un **manifest** (versions, hash, tailles) pour vérif d'intégrité.
5. Copie la police mushaf + licences dans `assets/fonts/`.

Sorties → `assets/corpus/corpus.db`, `assets/tafsir/...`, `assets/fonts/...`.
Pipeline **déterministe et idempotent** (même entrée → même db, même hash).
Attribution CC BY-NC conservée (écran À propos).

> Tailles cibles : corpus < ~30–40 Mo ; tafsir lazy (téléchargé au 1er besoin si trop lourd).
> Arbitrage embarqué/téléchargé tranché au sprint correspondant selon la taille mesurée.

## 7. Audio offline (port des contrats desktop)
- Téléchargement par verset (récitateur) : **fichier tmp unique** (anti-race), validation **magic bytes mp3**, déplacement atomique.
- Allowlist d'URL stricte (everyayah, audio.qurancdn.com/wbw). Purge couplée récitateur + audio-mot.
- Index en Drift (`audio_cache`) ; lecture via just_audio (source locale si en cache, sinon réseau + mise en cache).
- Timing mot/verset (segments) stocké avec le corpus pour l'audio-follow.
- Lecture arrière-plan via `audio_service` (`BaseAudioHandler`) : notif média, lockscreen, casque, CarPlay/Android Auto.

## 8. Rendu arabe (invariant sacré)
- `ArabicText` compose en **RTL** (`Directionality.rtl`) ; **interdiction de couper un mot ou ses harakat**.
- Stratégie par défaut : `Text.rich` avec la police mushaf, `softWrap` au niveau **mot** (pas de césure intra-mot). Mesure (texte, largeur) → layout **mise en cache** (perf scroll).
- **Risque harakat** (positionnement des diacritiques selon le moteur de texte) : si un golden révèle un défaut, basculer la primitive sur **glyphes pré-rendus** (le pipeline peut émettre des images/SVG par verset) — décidé au Sprint S2 selon mesure réelle.
- Mots = unités tappables (audio-mot, capture). Signe de pause `isWaqf` rendu plus petit (test de rendu dédié).
- Golden tests de non-coupure sur un échantillon de versets longs et étroits, plusieurs tailles.

## 9. Surfaces interstitielles (impl. par plateforme)
- **Deep links** type-safe (go_router) vers `program`/`reader`/verset/micro-session (cold & warm start).
- **Android** : Glance/RemoteViews via `home_widget` (MAJ via `workmanager` 1×/jour + après session) ; notif canaux « Révision » + « Lecture » (média) ; `TileService` natif (Quick Tile) ; Bubble API opt-in.
- **iOS** : widget WidgetKit (`home_widget` + extension Swift), App Intents/Siri, notifications + contrôles média ; Live Activity (option). Pas de bulle.
- Toutes les surfaces convergent vers le **même état** (verset courant, file) via les repos partagés.

## 10. Performance & qualité
- `ListView.builder` / `Sliver*` virtualisés ; mesure arabe mise en cache par (texte, largeur).
- Cold start rapide ; scroll Reader 60 fps (120 si dispo) — viser zéro jank (Impeller).
- Strict offline : aucun appel réseau au démarrage.
- `flutter analyze` zéro warning bloquant ; budget taille app suivi ; `integration_test` sur parcours clés.

## 11. Sécurité & vie privée
- Permissions minimales : audio réseau, `POST_NOTIFICATIONS` (Android 13+), `FOREGROUND_SERVICE` média. Bubble/overlay opt-in explicite. iOS : notifications opt-in.
- Pas de tracking tiers. Export/import local (chiffrable). Sync Pro = E2E ou backup chiffré (phase tardive).
