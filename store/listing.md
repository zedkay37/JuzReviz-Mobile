# Fiche Play Store — brouillon (PLAN.md R0.3)

## Titre (30 car. max)
FR : `JuzReviz — Coran & révision`  (29)
EN : `JuzReviz — Quran & Review`    (26)

## Description courte (80 car. max)
FR : `Mémorise le Coran : révision guidée, audio hors ligne après téléchargement.`
EN : `Memorize the Quran with smart review and audio available offline after download.`

## Description longue (FR)

JuzReviz t'aide à mémoriser le Coran et surtout à ne pas l'oublier.

**Révision intelligente** — L'app suit la fraîcheur de chaque verset dans le
temps. Chaque jour, l'onglet Aujourd'hui te dit exactement quoi revoir :
les versets fragiles d'abord, puis ceux qui refroidissent. Session « 3 minutes »
quand tu es pressé.

**Carte de chaleur** — Visualise d'un coup d'œil ton état de mémorisation sur
les 114 sourates : frais, à rafraîchir, à revoir, fragile.

**Récitation** — Écoute karaoké avec surlignage du verset en cours, 4
récitateurs, répétitions par âyah ou par passage, plages personnalisées
(de l'âyah X à l'âyah Y), audio en arrière-plan et hors-ligne après
téléchargement.

**Lecture & étude** — Mot-à-mot avec gloses françaises, traduction, tafsir
complet hors-ligne (FR/EN), mode voile pour s'auto-tester, disposition
Mushaf Madni (pack téléchargeable).

**Vie privée** — Aucun compte, aucune publicité et aucun tracking. Ta
progression, tes réglages et tes playlists restent stockés localement ; ils
peuvent être inclus dans les sauvegardes système selon les réglages du
téléphone. Les téléchargements de contenu contactent leurs hébergeurs, mais
n’envoient ni ta progression ni tes playlists. Une copie locale peut être
créée dans l’app ; le JSON n’est copié qu’à ta demande.

## Description longue (EN)

JuzReviz helps you memorize the Quran — and keep it memorized.

**Smart review** — The app tracks how fresh each verse is over time. Every
day, the Today tab tells you exactly what to review: fragile verses first,
then the ones cooling down. A "3 minutes" session when you're short on time.

**Heat map** — See your memorization state across all 114 surahs at a
glance: fresh, fading, due, fragile.

**Recitation** — Karaoke-style listening with live verse highlighting, 4
reciters, repeat by verse or passage, custom ranges (from ayah X to Y),
background and offline audio after download.

**Reading & study** — Word-by-word glosses, translation, full offline
tafsir (FR/EN), veil mode for self-testing, Madni Mushaf layout
(downloadable pack).

**Privacy** — No account, ads, or tracking. Your progress, settings, and
playlists are stored locally; depending on your phone settings, system backups
may include them. Content downloads contact their hosting providers, but never
upload your progress or playlists. The app can create a local backup, and only
copies its JSON when you explicitly ask it to.

## Data Safety (réponses Play Console)

| Question | Réponse |
|---|---|
| Collecte de données ? | Aucun compte, analytics, publicité ou envoi de progression par JuzReviz. Les requêtes de téléchargement exposent aux hébergeurs les informations réseau nécessaires (par exemple l’adresse IP) ; revalider la déclaration exacte selon les règles Play Console et les dépendances de la build soumise. |
| Données chiffrées en transit ? | Oui pour les téléchargements de contenu, effectués en HTTPS. |
| Suppression de données possible ? | Les données de l’app sont locales : elles peuvent être effacées depuis les réglages Android ou en désinstallant l’app. Des copies peuvent subsister dans une sauvegarde système gérée par l’utilisateur. |
| Domaines contactés | everyayah.com, audio.qurancdn.com (audio), verses.quran.foundation (polices mushaf). Les requêtes n’incluent ni compte, ni progression, ni playlist ; les hébergeurs peuvent traiter les métadonnées réseau nécessaires à la livraison. |
| SDK tiers de tracking/ads | Aucun. |

## Assets à produire (hors repo)
- Icône 512×512 PNG (fond opaque).
- Feature graphic 1024×500.
- 4–8 captures téléphone (Aujourd'hui, Coran heatmap, lecteur mot-à-mot,
  Réciter karaoké, tafsir) — prendre en thème Lanterne, FR.
- Catégorie : Éducation (ou Style de vie). Public : tout public.
- Politique de confidentialité : URL requise par Play Console — une page
  statique (GitHub Pages du repo) reprenant la section Vie privée suffit.
