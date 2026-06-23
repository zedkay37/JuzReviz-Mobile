import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

/// Hub « Profil » : régularité + accès aux réglages regroupés par intention.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    return LanternScaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LanternSpace.lg),
        children: [
          const _ProfileHeader(),
          const SettingSection('Réglages'),
          SettingGroup(
            children: [
              NavCard(
                icon: Icons.headphones,
                title: 'Récitation',
                subtitle: '${reciterById(s.reciter).name} · ${s.playbackRate}×',
                onTap: () => context.push('/profile/recitation'),
              ),
              NavCard(
                icon: Icons.menu_book,
                title: 'Lecture & affichage',
                subtitle: _readingSummary(s),
                onTap: () => context.push('/profile/reading'),
              ),
              NavCard(
                icon: Icons.local_fire_department,
                title: 'Révision',
                subtitle: s.masteryProfile == MasteryProfile.serenity
                    ? 'Sérénité'
                    : 'Excellence',
                onTap: () => context.push('/profile/revision'),
              ),
              NavCard(
                icon: Icons.palette_outlined,
                title: 'Apparence',
                subtitle: appThemeFromString(s.theme).label,
                onTap: () => context.push('/profile/appearance'),
              ),
            ],
          ),
          const SizedBox(height: LanternSpace.md),
          SettingGroup(
            children: [
              NavCard(
                icon: Icons.sync_alt,
                title: 'Données',
                subtitle: 'Export / import de l’état de révision',
                onTap: () => context.push('/profile/data'),
              ),
              NavCard(
                icon: Icons.info_outline,
                title: 'À propos',
                subtitle: 'Sources, attributions, vie privée',
                onTap: () => context.push('/profile/about'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _readingSummary(Settings s) {
    final lang = s.glossLang == 'en' ? 'EN' : 'FR';
    final wbw = s.readerWordByWord ? 'mot-à-mot' : 'arabe seul';
    return '$wbw · gloses $lang';
  }
}

/// En-tête du Profil : régularité + état de mémorisation + accès Programme.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final mastery = ref.watch(masteryControllerProvider).valueOrNull;
    final needsReview = ref.watch(decayQueueProvider).valueOrNull?.length ?? 0;
    final memorized = mastery?.memorizedSurahs.length ?? 0;
    final mastered = mastery?.mastered.length ?? 0;
    final fresh = streak == 0 && mastered == 0 && memorized == 0 && needsReview == 0;

    return Padding(
      padding: const EdgeInsets.all(LanternSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: LanternSpace.md, vertical: LanternSpace.lg),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(LanternSpace.radius),
              border: Border.all(color: t.border),
            ),
            child: fresh
                ? Column(
                    children: [
                      Text('Bienvenue',
                          style: TextStyle(
                              color: t.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Commence ta première lecture',
                          style: TextStyle(color: t.inkSoft, fontSize: 12)),
                    ],
                  )
                : Row(
                    children: [
                      _Stat(value: '$streak', label: 'jours'),
                      _Stat(value: _v(mastered), label: 'maîtrisés'),
                      _Stat(value: _v(memorized), label: 'mémorisées'),
                      _Stat(value: _v(needsReview), label: 'à revoir'),
                    ],
                  ),
          ),
          const SizedBox(height: LanternSpace.sm),
          FilledButton.icon(
            onPressed: () => context.push(fresh ? '/' : '/program'),
            icon: Icon(fresh ? Icons.menu_book : Icons.local_fire_department),
            label: Text(fresh ? 'Commencer' : 'Programme du jour'),
          ),
        ],
      ),
    );
  }

  // Un zéro brut décourage : tiret tant qu'aucune donnée n'existe.
  String _v(int n) => n == 0 ? '—' : '$n';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: t.ink, fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.inkSoft, fontSize: 10)),
        ],
      ),
    );
  }
}
