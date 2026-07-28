import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/study_preferences.dart';
import '../screens/course_path_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/import_screen.dart';
import '../screens/item_editor_screen.dart';
import '../screens/learning_hub_screen.dart';
import '../screens/library_screen.dart';
import '../screens/mission_screen.dart';
import '../screens/pronunciation_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/session_builder_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/study_screen.dart';
import '../screens/unit_guide_screen.dart';
import '../screens/unit_notes_screen.dart';
import '../state/app_state.dart';
import '../widgets/responsive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ResponsiveShell(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/learn',
            builder: (context, state) => const LearningHubScreen(),
          ),
          GoRoute(
            path: '/path',
            builder: (context, state) => const CoursePathScreen(),
          ),
          GoRoute(
            path: '/missions',
            builder: (context, state) => const MissionCatalogScreen(),
          ),
          GoRoute(
            path: '/mission/:unitIndex',
            builder: (context, state) => MissionPracticeScreen(
              unitIndex:
                  int.tryParse(state.pathParameters['unitIndex'] ?? '') ?? -1,
            ),
          ),
          GoRoute(
            path: '/unit/:unitIndex',
            builder: (context, state) => UnitGuideScreen(
              unitIndex:
                  int.tryParse(state.pathParameters['unitIndex'] ?? '') ?? -1,
            ),
          ),
          GoRoute(
            path: '/notes/:unitIndex',
            builder: (context, state) => UnitNotesScreen(
              unitIndex:
                  int.tryParse(state.pathParameters['unitIndex'] ?? '') ?? -1,
            ),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/library/new',
            builder: (context, state) => const ItemEditorScreen(),
          ),
          GoRoute(
            path: '/library/edit/:itemId',
            builder: (context, state) =>
                ItemEditorScreen(itemId: state.pathParameters['itemId']),
          ),
          GoRoute(
            path: '/import',
            builder: (context, state) => const ImportScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/session-builder',
            builder: (context, state) => const SessionBuilderScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/study',
        builder: (context, state) {
          final resume = state.uri.queryParameters['resume'] == 'true';
          final activeSession = resume
              ? ref.read(appControllerProvider).activeStudySession
              : null;
          final modeName = state.uri.queryParameters['mode'];
          final mode =
              activeSession?.mode ??
              StudyMode.values.firstWhere(
                (value) => value.name == modeName,
                orElse: () => StudyMode.mixed,
              );
          final unitIndex =
              activeSession?.unitIndex ??
              int.tryParse(state.uri.queryParameters['unit'] ?? '');
          return StudyScreen(
            mode: mode,
            unitIndex: unitIndex,
            resume: activeSession != null,
            customPlan: state.uri.queryParameters['custom'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/cards',
        builder: (context, state) {
          final kindName = state.uri.queryParameters['kind'];
          final kind = FlashcardKind.values.firstWhere(
            (value) => value.name == kindName,
            orElse: () => FlashcardKind.mixed,
          );
          final unitIndex = int.tryParse(
            state.uri.queryParameters['unit'] ?? '',
          );
          return FlashcardScreen(kind: kind, unitIndex: unitIndex);
        },
      ),
      GoRoute(
        path: '/pronunciation',
        builder: (context, state) => PronunciationScreen(
          unitIndex: int.tryParse(state.uri.queryParameters['unit'] ?? ''),
        ),
      ),
    ],
  );
});
