import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/routing/app_router.dart';
import 'package:juzreviz/data/audio/audio_controller.dart';
import 'package:juzreviz/data/settings/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // L'app se lance immédiatement ; l'audio en arrière-plan s'initialise après
  // (terminé bien avant la première lecture) → jamais d'écran noir au démarrage.
  unawaited(_initAudioBackground());
  runApp(const ProviderScope(child: JuzRevizApp()));
}

Future<void> _initAudioBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.juzreviz.audio',
      androidNotificationChannelName: 'Lecture',
      androidNotificationOngoing: true,
    );
    justAudioBackgroundReady = true;
  } catch (_) {
    justAudioBackgroundReady = false;
  }
}

class JuzRevizApp extends ConsumerStatefulWidget {
  const JuzRevizApp({super.key});

  @override
  ConsumerState<JuzRevizApp> createState() => _JuzRevizAppState();
}

class _JuzRevizAppState extends ConsumerState<JuzRevizApp> {
  final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // (Re)planifie le rappel quotidien au démarrage (persistance post-reboot).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = await ref.read(settingsControllerProvider.future);
      await ref
          .read(notificationServiceProvider)
          .apply(enabled: s.remindersEnabled, hhmm: s.reminderTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final theme = appThemeFromString(settings.theme);
    return MaterialApp.router(
      title: 'JuzReviz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(theme),
      routerConfig: _router,
      locale: settings.translationLang == 'en'
          ? const Locale('en')
          : const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
