import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

/// Décor « vivant » : halo de braise discret en bas de l'écran (lanterne).
/// Opt-in (`ambientDecor`) et respecte Reduce motion (statique si désactivé).
class LanternAmbient extends StatefulWidget {
  const LanternAmbient({super.key, this.animate = true});
  final bool animate;

  @override
  State<LanternAmbient> createState() => _LanternAmbientState();
}

class _LanternAmbientState extends State<LanternAmbient>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final painter = _c == null
        ? CustomPaint(painter: _GlowPainter(t.ember, 0.5))
        : AnimatedBuilder(
            animation: _c!,
            builder: (_, _) => CustomPaint(
              painter: _GlowPainter(t.ember, 0.35 + 0.35 * _c!.value),
              child: const SizedBox.expand(),
            ),
          );
    return IgnorePointer(child: SizedBox.expand(child: painter));
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.color, this.intensity);
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.05);
    final radius = size.width * 0.9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.16 * intensity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.intensity != intensity || old.color != color;
}
