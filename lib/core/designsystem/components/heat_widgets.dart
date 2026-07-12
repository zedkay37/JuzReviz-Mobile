import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/components/heat_labels.dart';
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
    this.showHeat = true,
    this.onTap,
    this.heroTag,
  });

  final SurahMeta meta;
  final SurahHeat heat;
  final bool scarred;

  /// `false` en mode « Explorer » : tuile neutre, focus navigation.
  final bool showHeat;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final dominantColor = t.heat(heat.dominant);
    final stateLabel = heatLabelFr(heat.dominant);
    final meccan = meta.revelation == Revelation.meccan;
    final tile = Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(
          color: showHeat
              ? dominantColor.withValues(alpha: heat.warmth * 0.8 + 0.15)
              : t.border,
          width: showHeat ? 1.4 : 1,
        ),
        gradient: showHeat
            ? LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  dominantColor.withValues(alpha: heat.warmth * 0.22),
                  t.surface,
                ],
              )
            : null,
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
                child: Text(
                  '${meta.number}',
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (showHeat && heat.hasFragile)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.fragile,
                    shape: BoxShape.circle,
                  ),
                ),
              if (showHeat && scarred)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(
                    Icons.local_fire_department,
                    size: 12,
                    color: t.scar,
                  ),
                ),
            ],
          ),
          Text(
            meta.transliteration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: t.ink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            showHeat
                ? heat.needsReview > 0
                      ? '$stateLabel · ${heat.needsReview} à revoir'
                      : '$stateLabel · à jour'
                : '${meccan ? 'Mecquoise' : 'Médinoise'} · ${meta.ayahCount} v.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.inkSoft, fontSize: 11),
          ),
        ],
      ),
    );
    final wrapped = heroTag != null
        ? Hero(
            tag: heroTag!,
            child: Material(type: MaterialType.transparency, child: tile),
          )
        : tile;
    final status = showHeat
        ? [
            stateLabel,
            if (heat.needsReview > 0) '${heat.needsReview} à revoir',
            if (heat.hasFragile) 'versets fragiles',
            if (scarred) 'cicatrice',
          ].join(', ')
        : '${meccan ? 'Mecquoise' : 'Médinoise'}, ${meta.ayahCount} versets';
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      label: 'Sourate ${meta.number}, ${meta.transliteration}',
      value: status,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LanternSpace.radius),
          child: wrapped,
        ),
      ),
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
    final interactive = onTap != null || onLongPress != null;
    final stateLabel = heatLabelFr(state);
    return Semantics(
      container: true,
      button: interactive,
      enabled: interactive,
      label: 'Verset $ayah',
      value: scarred ? '$stateLabel, cicatrice' : stateLabel,
      hint: onLongPress == null ? null : 'Appui long pour ouvrir les actions',
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: t.heatCellBackground(state),
              borderRadius: BorderRadius.circular(8),
              border: scarred ? Border.all(color: t.scar, width: 1.5) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$ayah',
              style: TextStyle(
                color: t.heatCellForeground(state),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
