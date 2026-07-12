import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/routing/app_router.dart';
import 'package:juzreviz/data/audio/audio_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerBundledLicenses();
  // Le package remplace le backend audio pendant son initialisation : son
  // contrat impose de terminer cette étape avant de créer un AudioPlayer.
  await _initAudioBackground();
  runApp(const ProviderScope(child: JuzRevizApp()));
}

void _registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    final amiriLicense = await rootBundle.loadString(
      'assets/fonts/AmiriQuran-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Amiri Quran'], amiriLicense);

    final tanzilNotice = await rootBundle.loadString(
      'assets/licenses/Tanzil-Quran-Text-NOTICE.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Tanzil Quran Text'], tanzilNotice);
  });
}

Future<void> _initAudioBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.juzreviz.audio',
      androidNotificationChannelName: 'Lecture',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_stat_juzreviz',
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

class _JuzRevizAppState extends ConsumerState<JuzRevizApp>
    with WidgetsBindingObserver {
  final _router = buildRouter();
  Timer? _dayBoundaryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayBoundaryRefresh();
    // (Re)planifie le rappel quotidien au démarrage (persistance post-reboot).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncReminderSettings());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTimeDerivedState();
      _scheduleDayBoundaryRefresh();
    }
  }

  void _refreshTimeDerivedState() {
    ref
      ..invalidate(atlasHeatProvider)
      ..invalidate(decayQueueProvider)
      ..invalidate(reviewSummaryProvider)
      ..invalidate(streakProvider)
      ..invalidate(hotZonesProvider);
  }

  void _scheduleDayBoundaryRefresh() {
    _dayBoundaryTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).add(const Duration(seconds: 1));
    _dayBoundaryTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      _refreshTimeDerivedState();
      _scheduleDayBoundaryRefresh();
    });
  }

  Future<void> _syncReminderSettings() async {
    try {
      final s = await ref.read(settingsControllerProvider.future);
      await ref
          .read(notificationServiceProvider)
          .apply(enabled: s.remindersEnabled, hhmm: s.reminderTime);
    } catch (_) {
      // Startup must stay independent from local notification state.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayBoundaryTimer?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.valueOrNull;
    if (settings == null) {
      return MaterialApp(
        title: 'JuzReviz',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppTheme.lanterne),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: _localizationsDelegates,
        home: _StartupGate(
          hasError: settingsAsync.hasError,
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
      );
    }
    final theme = appThemeFromString(settings.theme);
    return MaterialApp.router(
      title: 'JuzReviz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(theme),
      routerConfig: _router,
      // `contentLang` ne pilote que gloses/traduction/tafsir. L'interface
      // reste française tant qu'aucune localisation UI complète n'existe.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: _localizationsDelegates,
    );
  }
}

const _localizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class _StartupGate extends StatelessWidget {
  const _StartupGate({required this.hasError, required this.onRetry});

  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64)
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.accentSoft),
                        ),
                        child: Icon(
                          Icons.auto_stories,
                          color: t.accent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'JuzReviz',
                        style: TextStyle(
                          color: t.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (hasError) ...[
                        Text(
                          'Impossible de charger tes réglages locaux.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.inkSoft),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ] else ...[
                        Semantics(
                          label: 'Chargement de JuzReviz',
                          child: const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
