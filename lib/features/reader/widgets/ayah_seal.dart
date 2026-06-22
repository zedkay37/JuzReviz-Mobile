import 'package:flutter/material.dart';
import 'package:juzreviz/core/common/digits.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

/// Sceau d'ayah stylisé (numéro en chiffres arabes ou latins).
class AyahSeal extends StatelessWidget {
  const AyahSeal({super.key, required this.ayah, this.latin = false, this.size = 30});
  final int ayah;
  final bool latin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Semantics(
      label: 'Verset $ayah',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.accent.withValues(alpha: 0.7), width: 1.4),
          color: t.accent.withValues(alpha: 0.08),
        ),
        child: Text(
          latin ? '$ayah' : toArabicDigits(ayah),
          style: TextStyle(color: t.accent, fontSize: size * 0.42),
        ),
      ),
    );
  }
}
