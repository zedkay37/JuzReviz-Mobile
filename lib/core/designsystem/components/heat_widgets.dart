import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';

/// Tuile de chaleur d'une sourate (Atlas).
class HeatTile extends StatelessWidget {
  const HeatTile({
    super.key,
    required this.meta,
    required this.heat,
    required this.scarred,
    this.onTap,
    this.heroTag,
  });

  final SurahMeta meta;
  final SurahHeat heat;
  final bool scarred;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final dominantColor = t.heat(heat.dominant);
    final tile = Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(
          color: dominantColor.withValues(alpha: heat.warmth * 0.8 + 0.15),
          width: 1.4,
        ),
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            dominantColor.withValues(alpha: heat.warmth * 0.22),
            t.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.all(LanternSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: t.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${meta.number}',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (heat.hasFragile)
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: t.fragile, shape: BoxShape.circle),
                ),
              if (scarred)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(Icons.local_fire_department,
                      size: 12, color: t.scar),
                ),
            ],
          ),
          Text(
            meta.transliteration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: t.ink, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (heat.needsReview > 0)
            Text('${heat.needsReview} à revoir',
                style: TextStyle(color: t.inkSoft, fontSize: 11)),
        ],
      ),
    );
    final wrapped = heroTag != null
        ? Hero(tag: heroTag!, child: Material(type: MaterialType.transparency, child: tile))
        : tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LanternSpace.radius),
      child: wrapped,
    );
  }
}

/// Cellule de chaleur d'un verset (drill).
class HeatCell extends StatelessWidget {
  const HeatCell({
    super.key,
    required this.ayah,
    required this.state,
    this.scarred = false,
    this.onTap,
    this.onLongPress,
  });

  final int ayah;
  final HeatState state;
  final bool scarred;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final color = t.heat(state);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: state == HeatState.blank
              ? t.surfaceHigh
              : color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: scarred ? Border.all(color: t.scar, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text('$ayah',
            style: TextStyle(
                color: state == HeatState.blank ? t.inkSoft : t.background,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
