import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/reader/reader_screen.dart';

/// Onglet « Lire » : reprend là où on s'est arrêté (`currentVerseKey`),
/// affiche un coachmark léger au tout premier lancement.
class ReaderHome extends ConsumerStatefulWidget {
  const ReaderHome({super.key});

  @override
  ConsumerState<ReaderHome> createState() => _ReaderHomeState();
}

class _ReaderHomeState extends ConsumerState<ReaderHome> {
  bool _coachmarkChecked = false;

  void _maybeShowCoachmark(Settings s) {
    if (_coachmarkChecked || s.coachmarkSeen) return;
    _coachmarkChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(settingsControllerProvider.notifier)
          .edit((p) => p.copyWith(coachmarkSeen: true));
      showLanternSheet<void>(
        context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenue',
                style: TextStyle(
                    color: ctx.lantern.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const _Tip(Icons.touch_app, 'Touche l’écran pour masquer les contrôles.'),
            const _Tip(Icons.timer, 'Appui long sur un verset : Fragile / Maîtrisé.'),
            const _Tip(Icons.local_fire_department,
                'Le Programme t’apporte ce qui s’éteint, sans pression.'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Commencer'),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final metasAsync = ref.watch(surahMetasProvider);
    _maybeShowCoachmark(s);
    return metasAsync.when(
      loading: () =>
          const LanternScaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => LanternScaffold(body: LanternEmpty(message: 'Erreur : $e')),
      data: (metas) {
        final surah = int.tryParse(s.currentVerseKey.split(':').first) ?? 1;
        final meta = metas.where((m) => m.number == surah).firstOrNull;
        final count = meta?.ayahCount ?? 7;
        return ReaderScreen(selection: SelSurah(surah, 1, count));
      },
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: t.inkSoft))),
        ],
      ),
    );
  }
}
