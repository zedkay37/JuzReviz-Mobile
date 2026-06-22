import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/domain/model/enums.dart';

/// Badge d'état : fragile / maîtrisé / cicatrice (braise sur feuille verte).
class EmberBadge extends StatelessWidget {
  const EmberBadge({
    super.key,
    required this.state,
    this.scarred = false,
    this.size = 14,
  });

  final FlagState state;
  final bool scarred;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    if (state == FlagState.blank) return const SizedBox.shrink();
    final base = state == FlagState.fragile ? t.fragile : t.fresh;
    return Semantics(
      label: _label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: base,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          if (scarred)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(color: t.scar, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  String get _label => switch (state) {
        FlagState.fragile => 'Fragile',
        FlagState.mastered => scarred ? 'Maîtrisé (cicatrice)' : 'Maîtrisé',
        FlagState.blank => '',
      };
}

String heatLabelFr(HeatState s) => switch (s) {
      HeatState.fragile => 'Fragile',
      HeatState.fresh => 'Frais',
      HeatState.fading => 'À rafraîchir',
      HeatState.stale => 'À revoir',
      HeatState.blank => 'Vierge',
    };
