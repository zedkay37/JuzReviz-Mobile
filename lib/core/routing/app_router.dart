import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/atlas/atlas_screen.dart';
import 'package:juzreviz/features/atlas/surah_drill_screen.dart';
import 'package:juzreviz/features/playlists/playlist_detail_screen.dart';
import 'package:juzreviz/features/playlists/playlists_screen.dart';
import 'package:juzreviz/features/program/program_screen.dart';
import 'package:juzreviz/features/program/session_screen.dart';
import 'package:juzreviz/features/reader/reader_home.dart';
import 'package:juzreviz/features/reader/reader_screen.dart';
import 'package:juzreviz/features/settings/downloads_page.dart';
import 'package:juzreviz/features/settings/settings_pages.dart';
import 'package:juzreviz/features/settings/settings_screen.dart';

/// Reconstruit une [Selection] depuis les query params (deep links cold start).
Selection _selectionFromQuery(Map<String, String> q, Selection fallback) {
  if (q['juz'] != null) return SelJuz(int.tryParse(q['juz']!) ?? 1);
  final s = int.tryParse(q['s'] ?? '');
  if (s != null) {
    final from = int.tryParse(q['from'] ?? '1') ?? 1;
    final to = int.tryParse(q['to'] ?? '$from') ?? from;
    return SelSurah(s, from, to);
  }
  return fallback;
}

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _ShellScaffold(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (_, _) => const ReaderHome()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/atlas', builder: (_, _) => const AtlasScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/playlists', builder: (_, _) => const PlaylistsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/profile', builder: (_, _) => const SettingsScreen()),
            ]),
          ],
        ),
        GoRoute(path: '/program', builder: (_, _) => const ProgramScreen()),
        GoRoute(
            path: '/profile/recitation',
            builder: (_, _) => const RecitationPage()),
        GoRoute(
            path: '/profile/reading', builder: (_, _) => const ReadingPage()),
        GoRoute(
            path: '/profile/revision', builder: (_, _) => const RevisionPage()),
        GoRoute(
            path: '/profile/appearance',
            builder: (_, _) => const AppearancePage()),
        GoRoute(path: '/profile/data', builder: (_, _) => const DataPage()),
        GoRoute(
            path: '/profile/downloads',
            builder: (_, _) => const DownloadsPage()),
        GoRoute(path: '/profile/about', builder: (_, _) => const AboutPage()),
        GoRoute(
          path: '/read',
          builder: (ctx, st) => ReaderScreen(
            selection: st.extra as Selection? ??
                _selectionFromQuery(st.uri.queryParameters, const SelSurah(1, 1, 7)),
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
          builder: (ctx, st) =>
              SurahDrillScreen(surah: int.parse(st.pathParameters['n']!)),
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
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Lire'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Atlas'),
          NavigationDestination(
              icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music),
              label: 'Playlists'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }
}
