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

/// Hub « Profil » : accès aux réglages regroupés par intention.
/// (Régularité et file de révision vivent désormais dans l'onglet Aujourd'hui.)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final s = settingsAsync.valueOrNull;
    if (s == null) {
      return LanternScaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: settingsAsync.hasError
            ? LanternEmpty(
                message: 'Impossible de charger le profil.',
                action: TextButton.icon(
                  onPressed: () => ref.invalidate(settingsControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return LanternScaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.only(
          bottom: LanternSpace.lg,
          top: LanternSpace.sm,
        ),
        children: [
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
                icon: Icons.queue_music,
                title: 'Playlists',
                subtitle: 'Mes listes de lecture et révision',
                onTap: () => context.push('/playlists'),
              ),
              NavCard(
                icon: Icons.sync_alt,
                title: 'Données',
                subtitle: 'Téléchargements hors-ligne et sauvegarde locale',
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
    final lang = s.contentLang == 'en' ? 'EN' : 'FR';
    final wbw = s.readerWordByWord ? 'mot-à-mot' : 'arabe seul';
    return '$wbw · gloses $lang';
  }
}
