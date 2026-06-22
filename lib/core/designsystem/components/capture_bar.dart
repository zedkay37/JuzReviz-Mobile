import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

/// Barre de capture contextuelle (appui long sur un verset).
class CaptureBar extends StatelessWidget {
  const CaptureBar({
    super.key,
    required this.verseKey,
    required this.onFragile,
    required this.onMastered,
    this.onTafsir,
    this.onListen,
  });

  final String verseKey;
  final VoidCallback onFragile;
  final VoidCallback onMastered;
  final VoidCallback? onTafsir;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verset $verseKey',
            style: TextStyle(color: t.inkSoft, fontSize: LanternType.caption)),
        const SizedBox(height: LanternSpace.md),
        Row(
          children: [
            Expanded(
              child: _CaptureButton(
                icon: Icons.bolt,
                label: 'Fragile',
                color: t.fragile,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onFragile();
                },
              ),
            ),
            const SizedBox(width: LanternSpace.sm),
            Expanded(
              child: _CaptureButton(
                icon: Icons.spa,
                label: 'Maîtrisé',
                color: t.fresh,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onMastered();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: LanternSpace.sm),
        Row(
          children: [
            Expanded(
              child: _CaptureButton(
                icon: Icons.menu_book,
                label: 'Tafsir',
                color: t.accentSoft,
                onTap: onTafsir,
              ),
            ),
            const SizedBox(width: LanternSpace.sm),
            Expanded(
              child: _CaptureButton(
                icon: Icons.play_arrow,
                label: 'Écouter',
                color: t.accentSoft,
                onTap: onListen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LanternSpace.radius),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: LanternSpace.md),
          decoration: BoxDecoration(
            color: t.surfaceHigh,
            borderRadius: BorderRadius.circular(LanternSpace.radius),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: t.ink, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
