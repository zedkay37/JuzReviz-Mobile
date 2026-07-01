import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';
import 'package:path_provider/path_provider.dart';

Settings _s(WidgetRef ref) =>
    ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();

void _edit(WidgetRef ref, Settings Function(Settings) f) =>
    ref.read(settingsControllerProvider.notifier).edit(f);

// ----------------------------------------------------------------- Récitation

class RecitationPage extends ConsumerWidget {
  const RecitationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _s(ref);
    final t = context.lantern;
    return LanternScaffold(
      appBar: AppBar(title: const Text('Récitation')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LanternSpace.lg),
        children: [
          const SettingSection('Récitateur'),
          SettingGroup(
            children: [
              for (final r in reciters)
                ListTile(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _edit(ref, (p) => p.copyWith(reciter: r.id));
                  },
                  title: Text(r.name, style: TextStyle(color: t.ink)),
                  trailing: s.reciter == r.id
                      ? Icon(Icons.check_circle, color: t.accent)
                      : Icon(Icons.circle_outlined, color: t.inkSoft),
                ),
            ],
          ),
          const SettingSection('Lecture'),
          SettingGroup(
            children: [
              SliderRow(
                title: 'Vitesse',
                value: s.playbackRate,
                min: 0.5,
                max: 2,
                divisions: 6,
                valueLabel: '${s.playbackRate}×',
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(playbackRate: v)),
              ),
              ChoiceRow<AudioRepeatMode>(
                title: 'Répétition',
                value: s.repeatMode,
                options: const [
                  (AudioRepeatMode.off, 'Aucune'),
                  (AudioRepeatMode.ayah, 'Par âyah'),
                  (AudioRepeatMode.range, 'Par passage'),
                  (AudioRepeatMode.progressive, 'Progressif'),
                ],
                onChanged: (v) => _edit(ref, (p) => p.copyWith(repeatMode: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Lecture & affichage

class ReadingPage extends ConsumerWidget {
  const ReadingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _s(ref);
    const langs = [('fr', 'Français'), ('en', 'Anglais')];
    return LanternScaffold(
      appBar: AppBar(title: const Text('Lecture & affichage')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LanternSpace.lg),
        children: [
          const SettingSection('Interlinéaire'),
          SettingGroup(
            children: [
              SwitchRow(
                title: 'Mot-à-mot',
                subtitle: 'Glose sous chaque mot',
                value: s.readerWordByWord,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(readerWordByWord: v)),
              ),
              SwitchRow(
                title: 'Traduction',
                value: s.readerTranslation,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(readerTranslation: v)),
              ),
              ChoiceRow<String>(
                title: 'Langue',
                subtitle: 'Gloses, traduction et tafsir',
                value: s.contentLang == 'en' ? 'en' : 'fr',
                options: langs,
                onChanged: (v) => _edit(ref, (p) => p.copyWith(contentLang: v)),
              ),
            ],
          ),
          const SettingSection('Texte arabe'),
          SettingGroup(
            children: [
              SwitchRow(
                title: 'Chiffres latins',
                subtitle: 'Numéros d’ayah en chiffres occidentaux',
                value: s.latinAyahNumbers,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(latinAyahNumbers: v)),
              ),
              SwitchRow(
                title: 'Audio-mot',
                subtitle: s.readerWordByWord
                    ? 'Toucher un mot le récite'
                    : 'Nécessite le mot-à-mot',
                enabled: s.readerWordByWord,
                value: s.wordAudio,
                onChanged: (v) => _edit(ref, (p) => p.copyWith(wordAudio: v)),
              ),
            ],
          ),
          const SettingSection('Auto-test (voile)'),
          SettingGroup(
            children: [
              ChoiceRow<VeilMode>(
                title: 'Voile',
                subtitle: 'Masquer le texte pour s’auto-tester',
                value: s.veilMode,
                options: const [
                  (VeilMode.full, 'Tout visible'),
                  (VeilMode.firstWords, 'Premiers mots'),
                  (VeilMode.hidden, 'Masqué'),
                ],
                onChanged: (v) => _edit(ref, (p) => p.copyWith(veilMode: v)),
              ),
              if (s.veilMode == VeilMode.firstWords)
                SliderRow(
                  title: 'Mots révélés',
                  value: s.veilWords.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  valueLabel: '${s.veilWords}',
                  onChanged: (v) =>
                      _edit(ref, (p) => p.copyWith(veilWords: v.round())),
                ),
              SwitchRow(
                title: 'Mode focus',
                subtitle: 'Masquer toute l’interface',
                value: s.focusMode,
                onChanged: (v) => _edit(ref, (p) => p.copyWith(focusMode: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- Révision

class RevisionPage extends ConsumerWidget {
  const RevisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _s(ref);
    return LanternScaffold(
      appBar: AppBar(title: const Text('Révision')),
      body: ListView(
        padding: const EdgeInsets.all(LanternSpace.md),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: SettingSection('Profil de maîtrise'),
          ),
          ChoiceCard(
            title: 'Sérénité',
            description:
                'Seuils larges (frais < 180 j, à revoir < 365 j). Sans pression.',
            selected: s.masteryProfile == MasteryProfile.serenity,
            onTap: () => _edit(
              ref,
              (p) => p.copyWith(masteryProfile: MasteryProfile.serenity),
            ),
          ),
          const SizedBox(height: LanternSpace.sm),
          ChoiceCard(
            title: 'Excellence',
            description:
                'Exigeant (frais < 30 j, à revoir < 90 j). Pour viser la solidité.',
            selected: s.masteryProfile == MasteryProfile.excellence,
            onTap: () => _edit(
              ref,
              (p) => p.copyWith(masteryProfile: MasteryProfile.excellence),
            ),
          ),
          const SizedBox(height: LanternSpace.md),
          SettingGroup(
            children: [
              SwitchRow(
                title: 'Capture auto',
                subtitle: 'Marquer « maîtrisé » en fin de verset écouté',
                value: s.autoMaster,
                onChanged: (v) => _edit(ref, (p) => p.copyWith(autoMaster: v)),
              ),
              SwitchRow(
                title: 'Rappels de révision',
                value: s.remindersEnabled,
                onChanged: (v) {
                  _edit(ref, (p) => p.copyWith(remindersEnabled: v));
                  ref
                      .read(notificationServiceProvider)
                      .apply(enabled: v, hhmm: s.reminderTime);
                },
              ),
              if (s.remindersEnabled) _ReminderTimeRow(time: s.reminderTime),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderTimeRow extends ConsumerWidget {
  const _ReminderTimeRow({required this.time});
  final String time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    return ListTile(
      title: Text('Heure du rappel', style: TextStyle(color: t.ink)),
      trailing: Text(
        time,
        style: TextStyle(
          color: t.accent,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () async {
        final parts = time.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 8,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        );
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked == null) return;
        final hh = picked.hour.toString().padLeft(2, '0');
        final mm = picked.minute.toString().padLeft(2, '0');
        _edit(ref, (p) => p.copyWith(reminderTime: '$hh:$mm'));
        ref
            .read(notificationServiceProvider)
            .apply(enabled: true, hhmm: '$hh:$mm');
      },
    );
  }
}

// ------------------------------------------------------------------- Apparence

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _s(ref);
    final current = appThemeFromString(s.theme);
    return LanternScaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LanternSpace.lg),
        children: [
          const SettingSection('Thème'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LanternSpace.md,
              vertical: LanternSpace.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final theme in AppTheme.values)
                  ThemeSwatch(
                    theme: theme,
                    selected: current == theme,
                    onTap: () => _edit(ref, (p) => p.copyWith(theme: theme.id)),
                  ),
              ],
            ),
          ),
          const SettingSection('Confort'),
          SettingGroup(
            children: [
              SwitchRow(
                title: 'Couleur dynamique',
                subtitle: 'Dérivée du fond d’écran (Android), bridée lanterne',
                value: s.dynamicColor,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(dynamicColor: v)),
              ),
              SwitchRow(
                title: 'Garder l’écran allumé',
                value: s.keepScreenOn,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(keepScreenOn: v)),
              ),
              SwitchRow(
                title: 'Décor vivant',
                subtitle: 'Halo de braise discret pendant la lecture',
                value: s.ambientDecor,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(ambientDecor: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- Données

class DataPage extends ConsumerWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LanternScaffold(
      appBar: AppBar(title: const Text('Données')),
      body: ListView(
        padding: const EdgeInsets.only(top: LanternSpace.md),
        children: [
          SettingGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Téléchargements'),
                subtitle: const Text('Récitation hors-ligne par sourate'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/downloads'),
              ),
            ],
          ),
          const SizedBox(height: LanternSpace.md),
          SettingGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Exporter l’état de révision'),
                subtitle: const Text('Fichier de sauvegarde (+ presse-papiers)'),
                onTap: () => _export(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Importer'),
                subtitle: const Text('Depuis le fichier de sauvegarde, ou coller un JSON'),
                onTap: () => _import(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String> _backupPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/juzreviz_backup.json';
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final settings = _s(ref);
    final mastery =
        ref.read(masteryControllerProvider).valueOrNull ?? const MasteryState();
    final playlists =
        ref.read(playlistsControllerProvider).valueOrNull ?? const <Playlist>[];
    final payload = jsonEncode({
      'settings': settings.toJson(),
      'mastery': mastery.toJson(),
      'playlists': playlists.map((p) => p.toJson()).toList(),
    });
    final path = await _backupPath();
    await File(path).writeAsString(payload);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export enregistré'),
        content: Text('Fichier : $path\n\nAussi copié dans le presse-papiers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final backupFile = File(await _backupPath());
    final exists = await backupFile.exists();
    if (!context.mounted) return;
    String? raw;
    if (exists) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importer'),
          content: Text('Fichier de sauvegarde trouvé :\n${backupFile.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'paste'),
              child: const Text('Coller un JSON…'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'file'),
              child: const Text('Importer ce fichier'),
            ),
          ],
        ),
      );
      if (choice == 'file') {
        raw = await backupFile.readAsString();
      } else if (choice == 'paste') {
        if (!context.mounted) return;
        raw = await showDialog<String>(
          context: context,
          builder: (ctx) => const _ImportDialog(),
        );
      } else {
        return;
      }
    } else {
      raw = await showDialog<String>(
        context: context,
        builder: (ctx) => const _ImportDialog(),
      );
    }
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (map['settings'] is Map) {
        await ref
            .read(settingsRepositoryProvider)
            .save(
              Settings.fromJsonSanitized(
                (map['settings'] as Map).cast<String, dynamic>(),
              ),
            );
      }
      if (map['mastery'] is Map) {
        await ref
            .read(masteryRepositoryProvider)
            .save(
              MasteryState.fromJson(
                (map['mastery'] as Map).cast<String, dynamic>(),
              ),
            );
      }
      if (map['playlists'] is List) {
        await ref
            .read(playlistsRepositoryProvider)
            .save(
              (map['playlists'] as List)
                  .map(
                    (e) =>
                        Playlist.fromJson((e as Map).cast<String, dynamic>()),
                  )
                  .toList(),
            );
      }
      ref
        ..invalidate(settingsControllerProvider)
        ..invalidate(masteryControllerProvider)
        ..invalidate(playlistsControllerProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Import réussi.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON invalide.')));
    }
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();
  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importer (coller le JSON)'),
      content: TextField(controller: _ctrl, maxLines: 6, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Importer'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- À propos

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return LanternScaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(LanternSpace.md),
        children: [
          SettingGroup(
            children: [
              ListTile(
                title: Text('JuzReviz', style: TextStyle(color: t.ink)),
                subtitle: Text(
                  '« Le Coran qui vit dans ta journée. »',
                  style: TextStyle(color: t.inkSoft),
                ),
              ),
              ListTile(
                title: Text(
                  'Sources & attributions',
                  style: TextStyle(color: t.ink),
                ),
                subtitle: Text(
                  'Texte uthmani : Tanzil.net. Gloses, traductions & tafsir : '
                  'corpus word-by-word (CC BY-NC). Police arabe : Amiri Quran '
                  '(SIL OFL). Mushaf : polices QCF (KFGQPC).',
                  style: TextStyle(color: t.inkSoft),
                ),
              ),
              ListTile(
                title: Text('Vie privée', style: TextStyle(color: t.ink)),
                subtitle: Text(
                  'Aucune donnée ne quitte l’appareil. Aucun tracking.',
                  style: TextStyle(color: t.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
