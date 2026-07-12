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
import 'package:juzreviz/data/backup/backup_payload.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/features/program/known_surahs_sheet.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';
import 'package:path_provider/path_provider.dart';

void _edit(WidgetRef ref, Settings Function(Settings) f) =>
    ref.read(settingsControllerProvider.notifier).edit(f);

Widget _pendingSettingsPage(
  String title,
  WidgetRef ref, {
  required bool hasError,
  VoidCallback? onRetry,
}) {
  return LanternScaffold(
    contentMaxWidth: 760,
    appBar: AppBar(title: Text(title)),
    body: hasError
        ? LanternEmpty(
            message: 'Impossible de charger ces réglages.',
            action: TextButton.icon(
              onPressed:
                  onRetry ?? () => ref.invalidate(settingsControllerProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          )
        : const Center(child: CircularProgressIndicator()),
  );
}

// ----------------------------------------------------------------- Récitation

class RecitationPage extends ConsumerWidget {
  const RecitationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final s = settingsAsync.valueOrNull;
    if (s == null) {
      return _pendingSettingsPage(
        'Récitation',
        ref,
        hasError: settingsAsync.hasError,
      );
    }
    final t = context.lantern;
    return LanternScaffold(
      contentMaxWidth: 760,
      appBar: AppBar(title: const Text('Récitation')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LanternSpace.lg),
        children: [
          const SettingSection('Récitateur'),
          SettingGroup(
            children: [
              for (final r in reciters)
                ListTile(
                  selected: s.reciter == r.id,
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
    final settingsAsync = ref.watch(settingsControllerProvider);
    final s = settingsAsync.valueOrNull;
    if (s == null) {
      return _pendingSettingsPage(
        'Lecture & affichage',
        ref,
        hasError: settingsAsync.hasError,
      );
    }
    const langs = [('fr', 'Français'), ('en', 'Anglais')];
    return LanternScaffold(
      contentMaxWidth: 760,
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
                title: 'Couleurs tajwid',
                subtitle: 'Ghunnah (vert), madd (rouge), qalqalah (bleu)',
                value: s.tajweedColors,
                onChanged: (v) =>
                    _edit(ref, (p) => p.copyWith(tajweedColors: v)),
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
    final settingsAsync = ref.watch(settingsControllerProvider);
    final masteryAsync = ref.watch(masteryControllerProvider);
    final s = settingsAsync.valueOrNull;
    final mastery = masteryAsync.valueOrNull;
    if (s == null || mastery == null) {
      return _pendingSettingsPage(
        'Révision',
        ref,
        hasError: settingsAsync.hasError || masteryAsync.hasError,
        onRetry: () {
          ref
            ..invalidate(settingsControllerProvider)
            ..invalidate(masteryControllerProvider);
        },
      );
    }
    final memorizedCount = mastery.memorizedSurahs.length;
    return LanternScaffold(
      contentMaxWidth: 760,
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
                onChanged: (v) async {
                  final service = ref.read(notificationServiceProvider);
                  if (!v) {
                    await service.apply(enabled: false, hhmm: s.reminderTime);
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .edit((p) => p.copyWith(remindersEnabled: false));
                    return;
                  }
                  final applied = await service.apply(
                    enabled: true,
                    hhmm: s.reminderTime,
                  );
                  if (!context.mounted) return;
                  if (applied) {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .edit((p) => p.copyWith(remindersEnabled: true));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Rappel non activé. Autorise les notifications dans '
                          'les réglages du téléphone, puis réessaie.',
                        ),
                      ),
                    );
                  }
                },
              ),
              if (s.remindersEnabled) _ReminderTimeRow(time: s.reminderTime),
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Sourates mémorisées'),
                subtitle: Text(
                  memorizedCount == 0
                      ? 'Ajouter les sourates que tu connais'
                      : '$memorizedCount sourate${memorizedCount > 1 ? 's' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    showKnownSurahsSheet(context, manageExisting: true),
              ),
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
        final next = '$hh:$mm';
        final applied = await ref
            .read(notificationServiceProvider)
            .apply(enabled: true, hhmm: next);
        if (!context.mounted) return;
        if (applied) {
          await ref
              .read(settingsControllerProvider.notifier)
              .edit((p) => p.copyWith(reminderTime: next));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de programmer ce rappel.'),
            ),
          );
        }
      },
    );
  }
}

// ------------------------------------------------------------------- Apparence

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final s = settingsAsync.valueOrNull;
    if (s == null) {
      return _pendingSettingsPage(
        'Apparence',
        ref,
        hasError: settingsAsync.hasError,
      );
    }
    final current = appThemeFromString(s.theme);
    return LanternScaffold(
      contentMaxWidth: 760,
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
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: LanternSpace.sm,
              runSpacing: LanternSpace.md,
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
    final settingsAsync = ref.watch(settingsControllerProvider);
    final masteryAsync = ref.watch(masteryControllerProvider);
    final playlistsAsync = ref.watch(playlistsControllerProvider);
    final settingsReady = settingsAsync.valueOrNull != null;
    final masteryReady = masteryAsync.valueOrNull != null;
    final playlistsReady = playlistsAsync.valueOrNull != null;
    final backupReady = settingsReady && masteryReady && playlistsReady;
    final backupHasError =
        settingsAsync.hasError ||
        masteryAsync.hasError ||
        playlistsAsync.hasError;
    return LanternScaffold(
      contentMaxWidth: 760,
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
                leading: const Icon(Icons.save_outlined),
                title: const Text('Créer une sauvegarde locale'),
                subtitle: Text(
                  backupReady
                      ? 'Copie locale dans l’app · JSON copiable sur demande'
                      : 'Chargement des données…',
                ),
                onTap: backupReady ? () => _export(context, ref) : null,
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Importer'),
                subtitle: Text(
                  backupReady
                      ? 'Restaurer la copie locale ou coller un JSON'
                      : 'Chargement des données…',
                ),
                onTap: backupReady ? () => _import(context, ref) : null,
              ),
              if (backupHasError)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Données indisponibles'),
                  subtitle: const Text('Réessayer le chargement'),
                  onTap: () {
                    ref
                      ..invalidate(settingsControllerProvider)
                      ..invalidate(masteryControllerProvider)
                      ..invalidate(playlistsControllerProvider);
                  },
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
    late final String payload;
    try {
      final settings = await ref.read(settingsControllerProvider.future);
      final mastery = await ref.read(masteryControllerProvider.future);
      final playlists = await ref.read(playlistsControllerProvider.future);
      payload = BackupPayload(
        settings: settings,
        mastery: mastery,
        playlists: playlists,
      ).encode();
      final path = await _backupPath();
      await File(path).writeAsString(payload);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer la sauvegarde.')),
      );
      return;
    }
    if (!context.mounted) return;
    final copyJson = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sauvegarde locale créée'),
        content: const Text(
          'Une copie a été enregistrée dans l’espace géré par JuzReviz. Aucun '
          'fichier portable n’a été créé ni placé dans tes Documents. Selon la '
          'configuration du téléphone, cette copie peut être incluse dans une '
          'sauvegarde système.\n\nPour la conserver manuellement ailleurs, copie '
          'volontairement le JSON puis colle-le dans un emplacement sûr.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Copier le JSON'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    if (copyJson != true) return;
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copié dans le presse-papiers.')),
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
          content: const Text(
            'Une copie locale gérée par JuzReviz est disponible sur cet '
            'appareil.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'paste'),
              child: const Text('Coller un JSON…'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'file'),
              child: const Text('Restaurer la copie locale'),
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
    late final BackupPayload backup;
    try {
      backup = BackupPayload.decode(raw);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sauvegarde invalide ou incompatible.')),
      );
      return;
    }
    if (!context.mounted) return;

    final historyCount = {
      ...backup.mastery.fragile.keys,
      ...backup.mastery.mastered.keys,
    }.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: Text(
          'Cette action remplace les réglages, la progression et les playlists '
          'actuels par :\n\n'
          '• ${backup.mastery.memorizedSurahs.length} sourates mémorisées\n'
          '• $historyCount versets avec un historique\n'
          '• ${backup.playlists.length} playlists',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final previousSettings = await ref.read(settingsControllerProvider.future);
    final previousMastery = await ref.read(masteryControllerProvider.future);
    final previousPlaylists = await ref.read(
      playlistsControllerProvider.future,
    );
    var reminderFailed = false;
    try {
      await Future.wait([
        ref.read(settingsRepositoryProvider).save(backup.settings),
        ref.read(masteryRepositoryProvider).save(backup.mastery),
        ref.read(playlistsRepositoryProvider).save(backup.playlists),
      ]);
      final reminderApplied = await ref
          .read(notificationServiceProvider)
          .apply(
            enabled: backup.settings.remindersEnabled,
            hhmm: backup.settings.reminderTime,
          );
      if (backup.settings.remindersEnabled && !reminderApplied) {
        reminderFailed = true;
        await ref
            .read(settingsRepositoryProvider)
            .save(backup.settings.copyWith(remindersEnabled: false));
      }
      ref
        ..invalidate(settingsControllerProvider)
        ..invalidate(masteryControllerProvider)
        ..invalidate(playlistsControllerProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminderFailed
                ? 'Sauvegarde restaurée. Le rappel n’a pas pu être activé.'
                : 'Sauvegarde restaurée.',
          ),
        ),
      );
    } catch (_) {
      // Restauration best-effort de l'état précédent si une des trois
      // écritures échoue : aucune section ne doit rester à moitié importée.
      try {
        await Future.wait([
          ref.read(settingsRepositoryProvider).save(previousSettings),
          ref.read(masteryRepositoryProvider).save(previousMastery),
          ref.read(playlistsRepositoryProvider).save(previousPlaylists),
        ]);
        await ref
            .read(notificationServiceProvider)
            .apply(
              enabled: previousSettings.remindersEnabled,
              hhmm: previousSettings.reminderTime,
            );
      } catch (_) {
        // L'erreur principale reste signalée ; le prochain chargement relira
        // le dernier état que le stockage a réussi à conserver.
      }
      ref
        ..invalidate(settingsControllerProvider)
        ..invalidate(masteryControllerProvider)
        ..invalidate(playlistsControllerProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Restauration interrompue. Vérifie tes données avant de réessayer.',
          ),
        ),
      );
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
      contentMaxWidth: 760,
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
                  'Texte uthmani : Tanzil Project (tanzil.net), CC BY 3.0 ; '
                  'notice complète embarquée. Police arabe : Amiri Quran '
                  '(SIL OFL). Mushaf : polices QCF (KFGQPC). Les provenances '
                  'et licences exactes des gloses, traductions et tafsirs '
                  'restent à finaliser avant distribution.',
                  style: TextStyle(color: t.inkSoft),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: Text(
                  'Licences et notices',
                  style: TextStyle(color: t.ink),
                ),
                subtitle: Text(
                  'Consulter Tanzil, les polices et les composants open source',
                  style: TextStyle(color: t.inkSoft),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'JuzReviz',
                ),
              ),
              ListTile(
                title: Text('Vie privée', style: TextStyle(color: t.ink)),
                subtitle: Text(
                  'Aucun compte, aucune publicité et aucun tracking. La '
                  'progression, les réglages et les playlists sont stockés '
                  'localement ; selon les réglages du téléphone, ils peuvent '
                  'être inclus dans une sauvegarde système. Les téléchargements '
                  'contactent everyayah.com, audio.qurancdn.com et '
                  'verses.quran.foundation : ces hébergeurs reçoivent les '
                  'informations réseau nécessaires à la livraison, jamais ta '
                  'progression ni tes playlists.',
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
