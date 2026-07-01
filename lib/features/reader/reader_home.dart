import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/features/atlas/atlas_screen.dart';

/// Onglet « Coran » : navigateur unifié (liste ou carte de chaleur),
/// coachmark léger au tout premier lancement. Tap → lecteur.
class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  bool _coachmarkChecked = false;
  bool _grid = false;

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
        builder: (ctx) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenue',
                style: TextStyle(
                  color: ctx.lantern.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const _Tip(
                Icons.touch_app,
                'Appui long sur un verset : menu complet — fragile/maîtrisé, cicatrice, playlist, tafsir, écouter, sélection de plage.',
              ),
              const _Tip(
                Icons.view_day_outlined,
                'Bouton disposition (en haut du lecteur) : Flexible, Verset par verset, taille du texte, Mushaf.',
              ),
              const _Tip(
                Icons.tune,
                'Réglages de la barre audio : vitesse, répétitions, boucles, pause après âyah.',
              ),
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
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    _maybeShowCoachmark(s);

    return LanternScaffold(
      appBar: AppBar(
        title: const Text('Coran'),
        actions: [
          IconButton(
            tooltip: _grid ? 'Vue liste' : 'Carte de chaleur',
            icon: Icon(
                _grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: _grid ? const AtlasGridView() : _SurahListBody(settings: s),
    );
  }
}

class _SurahListBody extends ConsumerWidget {
  const _SurahListBody({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(surahMetasProvider);
    final heat = {
      for (final tile in ref.watch(atlasHeatProvider).valueOrNull ?? const [])
        tile.meta.number: tile.heat.warmth,
    };
    final resumeSurah =
        int.tryParse(settings.currentVerseKey.split(':').first) ?? 1;

    return metasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
      data: (metas) {
        final resume = metas.where((m) => m.number == resumeSurah).firstOrNull;
        return ListView.builder(
          itemCount: metas.length + (resume != null ? 1 : 0),
          itemBuilder: (_, i) {
            if (resume != null && i == 0) {
              return _ResumeCard(meta: resume, verseKey: settings.currentVerseKey);
            }
            final m = metas[i - (resume != null ? 1 : 0)];
            return _SurahRow(meta: m, warmth: heat[m.number] ?? 0);
          },
        );
      },
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.meta, required this.verseKey});
  final SurahMeta meta;
  final String verseKey;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final ayah = verseKey.split(':').last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LanternSpace.md,
        LanternSpace.md,
        LanternSpace.md,
        LanternSpace.sm,
      ),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(LanternSpace.radius),
          onTap: () => context.push(
            '/read',
            extra: SelSurah(meta.number, 1, meta.ayahCount),
          ),
          child: Container(
            padding: const EdgeInsets.all(LanternSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LanternSpace.radius),
              border: Border.all(color: t.accent),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.auto_stories, color: t.accent, size: 22),
                ),
                const SizedBox(width: LanternSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reprendre la lecture',
                        style: TextStyle(color: t.inkSoft, fontSize: 12),
                      ),
                      Text(
                        '${meta.transliteration} · verset $ayah',
                        style: TextStyle(
                          color: t.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.meta, required this.warmth});
  final SurahMeta meta;
  final double warmth;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return ListTile(
      onTap: () => context.push(
        '/read',
        extra: SelSurah(meta.number, 1, meta.ayahCount),
      ),
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text(
          '${meta.number}',
          style: TextStyle(color: t.accent, fontSize: 13),
        ),
      ),
      title: Text(meta.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text(
        '${meta.ayahCount} versets · ${meta.revelation == Revelation.meccan ? 'Mecquoise' : 'Médinoise'}'
        '${warmth > 0.02 ? ' · ${(warmth * 100).round()}% mémorisé' : ''}',
        style: TextStyle(color: t.inkSoft, fontSize: 12),
      ),
      trailing: Text(
        meta.arabicName,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: t.inkSoft,
          fontSize: 18,
          fontFamily: t.arabicFamily,
        ),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: t.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: t.inkSoft)),
          ),
        ],
      ),
    );
  }
}
