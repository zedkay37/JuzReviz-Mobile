const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Convertit un entier en chiffres arabes-indiens (sceau d'ayah).
String toArabicDigits(int n) =>
    n.toString().split('').map((c) {
      final d = int.tryParse(c);
      return d == null ? c : _arabicIndic[d];
    }).join();
