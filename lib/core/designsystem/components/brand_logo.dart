import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

/// Logo JuzReviz : croissant doré + étincelle (cohérent avec l'icône Android).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CrescentPainter(color ?? context.lantern.accent),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  _CrescentPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.50, h * 0.52), radius: w * 0.42));
    final inner = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.64, h * 0.42), radius: w * 0.37));
    canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), paint);

    // Étincelle à 4 branches.
    final cx = w * 0.40, cy = h * 0.34, r = w * 0.12, t = w * 0.035;
    final star = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + t, cy - t)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + t, cy + t)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - t, cy + t)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - t, cy - t)
      ..close();
    canvas.drawPath(star, paint..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_CrescentPainter old) => old.color != color;
}
