import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/routing/app_router.dart';
import 'package:juzreviz/data/settings/settings.dart';

void main() {
  runApp(const ProviderScope(child: JuzRevizApp()));
}

class JuzRevizApp extends ConsumerStatefulWidget {
  const JuzRevizApp({super.key});

  @override
  ConsumerState<JuzRevizApp> createState() => _JuzRevizAppState();
}

class _JuzRevizAppState extends ConsumerState<JuzRevizApp> {
  final _router = buildRouter();

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
