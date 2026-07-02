# PLAN — JuzReviz Mobile · plan ultime vers la release

> Source de vérité : **le code au tag courant**, pas les anciens docs.
> `PROGRESS.md`/`ROADMAP.md` décrivent des états antérieurs (ancienne nav,
> EmberBadge, décor vivant, 31 tests) — à lire comme archives.
> Qualité vérifiée à l'écriture de ce plan : `flutter analyze` 0 issue ·
> `flutter test` 51/51 · version `1.4.0+4`.

## 0. Ce que l'app EST aujourd'hui (vérifié dans le code)

- **Nav 4 onglets** : Aujourd'hui (file SRS du jour, streak, zones chaudes) ·
  Coran (liste/carte de chaleur unifiée, lecteur étude) · Réciter (composeur
  sourates/juz + plages d'âyât personnalisées + écran karaoké dédié) · Profil.
- **Un seul modèle d'état de mémorisation** (`HeatState`, décroissance
  temporelle testée en parité desktop) + cicatrice (manuelle ou implicite).
- **Lecteur** : 3 dispositions (Mushaf Madni téléchargeable ~90 Mo, Flexible,
  Verset par verset), voile d'auto-test, tafsir offline FR/EN, navigation
  d'âyah rapide (pastille + curseur), audio séquentiel avec répétitions.
- **Données** : 100 % local (JSON), export fichier + presse-papiers, import
  fusion. Réseau sortant limité à 3 hosts statiques allowlistés (audio + polices).
- **Release-ready côté config** : mécanisme keystore en place (fallback debug),
  permissions minimales, `UIBackgroundModes: audio` iOS, vie privée exacte.

## R0 — Bloquants release (dans l'ordre, rien d'autre avant)

1. **Keystore de release** *(toi uniquement — secret)*
   - Générer : `keytool -genkey -v -keystore juzreviz-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   - Copier `android/key.properties.example` → `android/key.properties`, remplir.
   - Stocker le `.jks` + mots de passe hors du repo (gestionnaire de mots de
     passe + sauvegarde froide). **Perdre ce fichier = ne plus jamais pouvoir
     mettre à jour l'app.**
   - Vérif : `flutter build appbundle --release` puis
     `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
     ne montre plus `CN=Android Debug`.
2. **Recette complète sur appareil** (une session, checklist §R0.bis).
3. **Play Console** : compte, fiche (titre, description FR/EN, captures,
   icône 512, feature graphic), **Data Safety** : déclarer « aucune collecte »,
   mentionner les 3 domaines contactés (everyayah.com, audio.qurancdn.com,
   quran.foundation — fichiers statiques).
4. **Piste de test interne** (upload AAB) → toi + 2-3 proches, 1 semaine.
5. **Production** en rollout progressif (10 % → 50 % → 100 %).

## R0.bis — Checklist de recette device (avant chaque release)

- [ ] Installation propre : onboarding coachmark, premier lancement sans réseau.
- [ ] Aujourd'hui : file vide (état doux) puis file remplie après marquages.
- [ ] Coran : liste ↔ carte de chaleur, reprise de lecture, saut d'âyah (défile
      sans lancer l'audio), voile, tafsir, menu verset complet.
- [ ] Réciter : sélection sourates + juz + **plage personnalisée (appui long)**,
      karaoké (surlignage suit l'audio), saut d'âyah (reprend l'audio),
      enchaînement de sourate, écran verrouillé → l'audio continue
      (sur MIUI : vérifier « Aucune restriction » batterie d'abord).
- [ ] Mushaf : téléchargement pack (~90 Mo), coupure réseau en cours de
      téléchargement → reprise propre.
- [ ] Profil : chaque sous-écran, export fichier → réimport → état identique.
- [ ] Rappel quotidien : notification reçue à l'heure choisie (app fermée).
- [ ] Thèmes ×4 : aucun texte illisible sur les écrans principaux.
- [ ] Rotation + tablette/paysage : lecteur borné à 720 px, pas d'overflow.

## R1 — Finitions produit (après première release interne, avant prod large)

| # | Chantier | Décision/état |
|---|---|---|
| 1 | **Gloses : passe qualité corpus complet** | 2 fautes corrigées sur la sourate 5 seulement. Écrire un script `tools/` qui détecte mots anglais/fautes récurrentes dans les gloses FR des 114 sourates, corriger par lots. C'est LE risque crédibilité. |
| 2 | **Cicatrice** | Décision ouverte : la rétrograder en badge d'historique (critique initiale) ou garder l'action de premier plan. Trancher après retours des testeurs internes. |
| 3 | **Guidance batterie MIUI/surcouches** | L'audio en arrière-plan est tué par MIUI & co. Ajouter une carte one-time dans Réciter : « L'audio se coupe ? → réglage batterie » avec lien vers les paramètres. |
| 4 | **Karaoké mot-à-mot** | Bloqué par l'absence de données de segments audio (D5). Ne pas promettre tant que la source de timing n'existe pas. |
| 5 | **Vue Juz de la carte de chaleur** | Jamais livrée (le modèle `JuzHeat` mort a été supprimé). À refaire proprement si demandée par les testeurs, sinon abandonner. |

## R2 — Post-release (itérations)

- **Monitoring crash opt-in** (Sentry ou Crashlytics) — aujourd'hui : zéro
  télémétrie. Si ajouté : opt-in explicite + mise à jour de la page Vie privée
  et de Data Safety. Sans ça, les crashs terrain sont invisibles.
- **Minification R8** (`minifyEnabled`) pour réduire l'AAB : exige d'écrire les
  règles ProGuard pour just_audio/audio_service/flutter_local_notifications
  et une recette device complète derrière.
- **iOS** : build + TestFlight (config déjà saine ; nécessite Mac + compte Apple).
- **Surfaces natives** (widgets home, Quick Tile) — P8 historique, valeur réelle
  à valider avant d'investir.
- **Sync/compte Pro, IAP** — P12/P13 historique. Rien tant que la base
  mono-appareil n'est pas éprouvée.

## Hygiène continue

- **Docs** : marquer `PROGRESS.md` et le suivi de `ROADMAP.md` comme archives
  (bandeau en tête) plutôt que les maintenir en double du code.
- **Méthode qui a fait ses preuves dans ce projet — la garder** :
  1. Savepoint (`commit + push + tag`) AVANT tout chantier.
  2. Capture d'écran réelle → diagnostic dans le code → fix ciblé
     (jamais de refonte à l'aveugle).
  3. `flutter analyze` + `flutter test` verts avant tout commit.
  4. Un réglage qui n'est pas branché à un comportement réel ne doit pas
     exister dans `Settings` ni dans l'UI.
  5. Incrémenter `version:` de pubspec à chaque tag (le Store refuse un
     `versionCode` réutilisé).

## Restart handle

- **Changed** : voir `git log` — chaque tag `vX.Y.Z` est un savepoint testable.
- **Unverified** : rendu device des derniers changements (focus, mushaf unique).
- **Rollback** : `git checkout <tag>` précédent.
- **Do-not-touch** : `assets/corpus/*` (généré), `lib/domain/mastery/mastery.dart`
  (parité desktop testée), secrets de signature (jamais dans le repo).
- **Next safe action** : R0.1 — générer le keystore.
