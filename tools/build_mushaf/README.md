# Pack Moushaf (QCF par page)

Active les dispositions **Madni Mushaf** / **Tajweed Madni Mushaf** du lecteur.
Le code de rendu (`MushafView`) et la détection de présence sont déjà en place :
le mode s'active automatiquement dès que les assets sont embarqués.

## 1. Récupérer le pack QPC v1

Depuis les ressources « QPC v1 » du Quran Complex / quran.com :

- **Polices** : `QCF_P001.ttf` … `QCF_P604.ttf` (une par page).
  → renommer en `qcf_p1.ttf` … `qcf_p604.ttf` et placer dans
  `tools/build_mushaf/source/fonts/`.
- **Mise en page** : exporter la table mot-à-mot (page, ligne, verset, glyphe
  `code_v1`) au format attendu (voir en-tête de `build_mushaf.dart`) dans
  `tools/build_mushaf/source/words.json`.

## 2. Générer les assets

```bash
dart run tools/build_mushaf/build_mushaf.dart
```

Produit `assets/mushaf/pages.json` et imprime le bloc `pubspec.yaml` à coller
(asset `pages.json` + familles de polices `qcf_p1`…`qcf_p604`).

## 3. Copier les polices et déclarer dans pubspec

```bash
cp tools/build_mushaf/source/fonts/*.ttf assets/mushaf/fonts/
```

Colle le bloc imprimé dans `pubspec.yaml`, puis `flutter pub get`.

## Notes

- Sans ce pack, `MushafRepository.isAvailable()` renvoie `false` et les cartes
  Mushaf restent désactivées (l'app reste sur Flexible / Verset par verset).
- Le **Tajweed** réutilise le même moteur ; il faut la variante de police QCF
  tajwid (ou une table de couleurs par glyphe) — étape suivante une fois la
  vue Madni validée.
- Licence : vérifier les conditions d'usage des polices QCF avant distribution.
