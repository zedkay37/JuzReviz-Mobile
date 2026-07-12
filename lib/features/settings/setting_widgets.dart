import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

/// Brique premium pour les réglages : titre de section discret.
class SettingSection extends StatelessWidget {
  const SettingSection(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LanternSpace.lg,
        LanternSpace.lg,
        LanternSpace.lg,
        LanternSpace.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: t.accent,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Conteneur « carte » regroupant des réglages (surfaces premium arrondies).
class SettingGroup extends StatelessWidget {
  const SettingGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i != children.length - 1) {
        separated.add(
          Divider(height: 1, color: t.background.withValues(alpha: 0.5)),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(LanternSpace.radius),
          border: Border.all(color: t.surfaceHigh),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: separated),
      ),
    );
  }
}

/// Carte de navigation (hub Réglages → sous-écran).
class NavCard extends StatelessWidget {
  const NavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LanternSpace.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: t.accent, size: 20),
            ),
            const SizedBox(width: LanternSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur premium (titre + sous-titre).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SwitchListTile(
        value: value,
        onChanged: !enabled
            ? null
            : (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
        secondary: icon == null ? null : Icon(icon, color: t.inkSoft),
        title: Text(title, style: TextStyle(color: t.ink, fontSize: 15)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: t.inkSoft, fontSize: 12)),
      ),
    );
  }
}

/// Choix multiple en pastilles (intuitif, sans overflow — remplace les dropdowns).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });
  final String title;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: t.ink, fontSize: 15)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(color: t.inkSoft, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (v, label) in options)
                      _Pill(
                        label: label,
                        enabled: enabled,
                        selected: v == value,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(v);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 48,
              minHeight: 48,
              maxWidth: MediaQuery.sizeOf(context).width - 64,
            ),
            child: AnimatedContainer(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : LanternMotion.fast,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected && enabled
                    ? t.accent.withValues(alpha: 0.18)
                    : t.surfaceHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected && enabled ? t.accent : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: !enabled
                      ? t.inkFaint
                      : selected
                      ? t.accent
                      : t.inkSoft,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur premium avec valeur affichée en direct.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: t.ink, fontSize: 15),
                ),
              ),
              const SizedBox(width: LanternSpace.sm),
              Text(
                valueLabel,
                style: TextStyle(
                  color: t.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: t.accent,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Carte de choix descriptive (ex. profil de maîtrise).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    void activate() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: true,
      inMutuallyExclusiveGroup: true,
      label: title,
      value: description,
      onTap: activate,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: activate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: AnimatedContainer(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : LanternMotion.fast,
              padding: const EdgeInsets.all(LanternSpace.md),
              decoration: BoxDecoration(
                color: selected ? t.accent.withValues(alpha: 0.10) : t.surface,
                borderRadius: BorderRadius.circular(LanternSpace.radius),
                border: Border.all(
                  color: selected ? t.accent : t.surfaceHigh,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? t.accent : t.inkSoft,
                    size: 20,
                  ),
                  const SizedBox(width: LanternSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: t.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: t.inkSoft,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de prévisualisation d'un thème (fond + accent).
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
  });
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensFor(theme);
    final t = context.lantern;
    void activate() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: true,
      inMutuallyExclusiveGroup: true,
      label: theme.label,
      onTap: activate,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: activate,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 72),
            child: Column(
              children: [
                AnimatedContainer(
                  duration:
                      MediaQuery.maybeOf(context)?.disableAnimations ?? false
                      ? Duration.zero
                      : LanternMotion.fast,
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: tokens.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? t.accent : tokens.surfaceHigh,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    theme.label.split(' ').first,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? t.accent : t.inkSoft,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
