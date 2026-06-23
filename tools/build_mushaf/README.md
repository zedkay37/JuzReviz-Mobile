# Pack Moushaf (QCF par page)

Active les dispositions **Madni Mushaf** / **Tajweed Madni Mushaf** du lecteur.
Le code de rendu (`MushafView`) et la détection de présence sont déjà en place :
le mode s'active automatiquement dès que les assets sont embarqués.
La **famille de police** attendue par le rendu est `p<page>` (ex. `p1`, `p604`).

## 1. Récupérer le pack QPC v1 (Quran Foundation / QUL)

- **Polices** (TTF, une par page, déjà nommées `p1.ttf` … `p604.ttf`) :
  `https://verses.quran.foundation/fonts/quran/hafs/v1/ttf/p{1..604}.ttf`
  → placer dans `tools/build_mushaf/source/fonts/`.
  Miroirs GitHub : `nuqayah/qpc-fonts`, `quranwbw/qpc-fonts`, `adnan/qpc-fonts`.

- **Mise en page** (mushaf id **2** = QCF v1), par chapitre :
  `https://apis.quran.foundation/content/api/v4/verses/by_chapter/{1..114}`
  `?words=true&word_fields=code_v1,line_number,page_number&mushaf=2`
  (l'API peut requérir un client_id/secret gratuit via le portail Quran Foundation.)
  Transformer la réponse en `tools/build_mushaf/source/words.json` au format
  attendu (voir en-tête de `build_mushaf.dart`) : un objet par mot
  `{ page, line, key:"s:a", code:<code_v1>, type:"word"|"surah"|"basmalah"|"end" }`.

  Alternative sans API : exports « glyph-based » de la **Quranic Universal
  Library** (qul.tarteel.ai/docs/glyph-based).

### Récupération automatique (recommandé)

Un seul script télécharge polices + mise en page dans `source/` :

```bash
dart run tools/build_mushaf/fetch_qpc.dart    # 604 polices + words.json
```

C'est l'**unique** moment où le réseau est utilisé : tout est ensuite embarqué
dans l'APK. À l'exécution, l'app est **100 % offline** pour le moushaf.

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
