# Pack Moushaf (QCF par page)

Active les dispositions **Madni Mushaf** / **Tajweed Madni Mushaf** du lecteur.

## Modèle : pages embarquées + polices téléchargeables

- **Mise en page** : `assets/mushaf/pages.json` est **généré et commité** (≈2,3 Mo).
  Aucune action requise pour l'avoir.
- **Polices QCF** (≈90 Mo, 604 fichiers) : **téléchargées à la demande** par l'app
  dans son stockage (offline-first après le 1er téléchargement). L'APK reste léger.

Côté app :
- **Lire → bouton disposition** : choisir *Madni Mushaf* propose le téléchargement
  du pack si absent (progression inline), puis active la vue.
- **Profil → Données → Téléchargements → Pack Mushaf** : télécharger / supprimer.

La police de chaque page est chargée paresseusement (`FontLoader`) depuis le
stockage — seules les pages visibles sont en mémoire.

## Régénérer `pages.json` (optionnel)

Seulement si la mise en page doit être refaite. Nécessite le réseau.

```bash
dart run tools/build_mushaf/fetch_qpc.dart --layout   # → source/words.json
dart run tools/build_mushaf/build_mushaf.dart         # → assets/mushaf/pages.json
```

Sources (mushaf id **2** = QCF v1) :
- Layout : `https://api.quran.com/api/v4/verses/by_page/{1..604}?words=true&word_fields=code_v1,line_number,page_number,char_type_name`
- Polices (téléchargées par l'app au runtime) :
  `https://verses.quran.foundation/fonts/quran/hafs/v1/ttf/p{1..604}.ttf`

## Notes

- Le **Tajweed** réutilise pour l'instant la police Madni (pas la variante
  couleur) — étape suivante : police/données tajwid par glyphe.
- Licence : vérifier les conditions d'usage des polices QCF avant distribution.
