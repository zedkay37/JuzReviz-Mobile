import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

/// Scaffold edge-to-edge thémé Lanterne (gestion `SafeArea` optionnelle).
class LanternScaffold extends StatelessWidget {
  const LanternScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeArea = true,
    this.contentMaxWidth,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeArea;

  /// Largeur de lecture confortable pour les écrans de listes/formulaires.
  /// Laisser `null` pour les vues immersives (Mushaf, Atlas, lecteur).
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    Widget content = body;
    if (contentMaxWidth case final maxWidth?) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }
    if (safeArea) {
      content = SafeArea(
        // Le Scaffold/AppBar consomme déjà l'inset supérieur.
        top: appBar == null,
        bottom: bottomNavigationBar == null,
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: t.background,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: content,
    );
  }
}

/// État vide avec filigrane basmala + micro-copy douce (jamais d'écran brut).
class LanternEmpty extends StatelessWidget {
  const LanternEmpty({
    super.key,
    required this.message,
    this.icon,
    this.action,
  });
  final String message;
  final IconData? icon;

  /// CTA optionnel (ex. « Ajouter des passages »).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(LanternSpace.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - LanternSpace.lg * 2)
                      .clamp(0, double.infinity)
                      .toDouble()
                : 0,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      'بِسْمِ ٱللَّهِ',
                      style: TextStyle(
                        fontFamily: t.arabicFamily,
                        fontSize: 40,
                        color: t.inkSoft.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: LanternSpace.md),
                if (icon != null) ...[
                  Icon(icon, color: t.inkSoft, size: 28),
                  const SizedBox(height: LanternSpace.sm),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.inkSoft, fontSize: 14),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: LanternSpace.md),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
