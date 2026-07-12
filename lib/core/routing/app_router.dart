import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/atlas/surah_drill_screen.dart';
import 'package:juzreviz/features/playlists/compose_screen.dart';
import 'package:juzreviz/features/playlists/playlist_detail_screen.dart';
import 'package:juzreviz/features/playlists/playlists_screen.dart';
import 'package:juzreviz/features/program/program_screen.dart';
import 'package:juzreviz/features/program/session_screen.dart';
import 'package:juzreviz/features/reader/reader_home.dart';
import 'package:juzreviz/features/reader/reader_screen.dart';
import 'package:juzreviz/features/reader/recitation_screen.dart';
import 'package:juzreviz/features/settings/downloads_page.dart';
import 'package:juzreviz/features/settings/settings_pages.dart';
import 'package:juzreviz/features/settings/settings_screen.dart';

/// Reconstruit une [Selection] depuis les query params (deep links cold start).
Selection selectionFromQuery(Map<String, String> q, Selection fallback) {
  if (q['juz'] != null) {
    final juz = int.tryParse(q['juz']!);
    return juz != null && juz >= 1 && juz <= 30 ? SelJuz(juz) : fallback;
  }
  final s = int.tryParse(q['s'] ?? '');
  if (s != null && s >= 1 && s <= 114) {
    final from = (int.tryParse(q['from'] ?? '1') ?? 1).clamp(1, 286);
    final to = (int.tryParse(q['to'] ?? '$from') ?? from).clamp(from, 286);
    return SelSurah(s, from, to);
  }
  return fallback;
}

String? _initialVerseFromQuery(Map<String, String> query) {
  final raw = query['at'];
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null ||
      ayah == null ||
      surah < 1 ||
      surah > 114 ||
      ayah < 1 ||
      ayah > 286) {
    return null;
  }
  return '$surah:$ayah';
}

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ShellScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ProgramScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/coran', builder: (_, _) => const QuranScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/reciter', builder: (_, _) => const ComposeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/playlists', builder: (_, _) => const PlaylistsScreen()),
    GoRoute(
      path: '/profile/recitation',
      builder: (_, _) => const RecitationPage(),
    ),
    GoRoute(path: '/profile/reading', builder: (_, _) => const ReadingPage()),
    GoRoute(path: '/profile/revision', builder: (_, _) => const RevisionPage()),
    GoRoute(
      path: '/profile/appearance',
      builder: (_, _) => const AppearancePage(),
    ),
    GoRoute(path: '/profile/data', builder: (_, _) => const DataPage()),
    GoRoute(
      path: '/profile/downloads',
      builder: (_, _) => const DownloadsPage(),
    ),
    GoRoute(path: '/profile/about', builder: (_, _) => const AboutPage()),
    GoRoute(
      path: '/read',
      builder: (ctx, st) => ReaderScreen(
        selection:
            st.extra as Selection? ??
            selectionFromQuery(st.uri.queryParameters, const SelSurah(1, 1, 7)),
        initialVerseKey: _initialVerseFromQuery(st.uri.queryParameters),
      ),
    ),
    GoRoute(
      path: '/recite',
      builder: (ctx, st) => RecitationScreen(
        selection:
            st.extra as Selection? ??
            selectionFromQuery(st.uri.queryParameters, const SelSurah(1, 1, 7)),
      ),
    ),
    GoRoute(
      path: '/session',
      builder: (ctx, st) => SessionScreen(
        selection: st.extra as Selection? ?? const SelReview('', []),
      ),
    ),
    GoRoute(
      path: '/atlas/surah/:n',
      builder: (ctx, st) => SurahDrillScreen(
        surah: switch (int.tryParse(st.pathParameters['n'] ?? '')) {
          final value? when value >= 1 && value <= 114 => value,
          _ => 1,
        },
      ),
    ),
    GoRoute(
      path: '/playlists/:id',
      builder: (ctx, st) =>
          PlaylistDetailScreen(playlistId: st.pathParameters['id']!),
    ),
  ],
);

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Scaffold(
      backgroundColor: t.background,
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: t.surface,
        indicatorColor: t.accent.withValues(alpha: 0.2),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Aujourd’hui',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Coran',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq),
            selectedIcon: Icon(Icons.graphic_eq),
            label: 'Réciter',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
