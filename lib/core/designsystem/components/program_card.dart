import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/components/ember_badge.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/enums.dart';

/// Carte « programme du jour » pour un verset à revoir.
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    super.key,
    required this.verseKey,
    required this.title,
    required this.state,
    required this.count,
    this.onTap,
  });

  final String verseKey;
  final String title;
  final HeatState state;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LanternSpace.radius),
      child: Container(
        padding: const EdgeInsets.all(LanternSpace.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(LanternSpace.radius),
          border: Border.all(color: t.heat(state).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: t.heat(state),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: LanternSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: t.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text('$verseKey · ${heatLabelFr(state)}',
                      style: TextStyle(color: t.inkSoft, fontSize: 12)),
                ],
              ),
            ),
            if (count > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('×$count',
                    style: TextStyle(color: t.scar, fontSize: 13)),
              ),
            Icon(Icons.chevron_right, color: t.inkSoft),
          ],
        ),
      ),
    );
  }
}
