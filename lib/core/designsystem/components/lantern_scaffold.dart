import 'package:flutter/material.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';

/// Scaffold edge-to-edge thémé Lanterne (gestion `SafeArea` optionnelle).
class LanternScaffold extends StatelessWidget {
  const LanternScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeArea = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Scaffold(
      backgroundColor: t.background,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: safeArea ? SafeArea(child: body) : body,
    );
  }
}

/// État vide avec filigrane basmala + micro-copy douce (jamais d'écran brut).
class LanternEmpty extends StatelessWidget {
  const LanternEmpty({super.key, required this.message, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
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
          const SizedBox(height: 16),
          if (icon != null) Icon(icon, color: t.inkSoft, size: 28),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.inkSoft, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
