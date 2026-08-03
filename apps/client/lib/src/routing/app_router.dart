import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/study_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_interaction_preferences.dart';
import '../screens/course_path_screen.dart';
import '../screens/content_quality_screen.dart';
import '../screens/data_health_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/group_organizer_screen.dart';
import '../screens/home_screen.dart';
import '../screens/import_screen.dart';
import '../screens/item_editor_screen.dart';
import '../screens/learning_hub_screen.dart';
import '../screens/library_screen.dart';
import '../screens/mission_screen.dart';
import '../screens/personalization_screen.dart';
import '../screens/pronunciation_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/session_builder_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/study_screen.dart';
import '../screens/unit_guide_screen.dart';
import '../screens/unit_notes_screen.dart';
import '../state/app_state.dart';
import '../widgets/responsive_shell.dart';

NoTransitionPage<void> _topLevelTabPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

class _SubjectScopedContent extends ConsumerWidget {
  const _SubjectScopedContent({required this.scope, required this.child});

  final String scope;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(
      appControllerProvider.select(
        (state) => (
          state.activeSubjectId,
          state.preferences.activeSubjectChangedAt?.microsecondsSinceEpoch ?? 0,
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey((scope, identity.$1, identity.$2)),
      child: child,
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final branchNavigatorKeys = List<GlobalKey<NavigatorState>>.generate(
    5,
    (index) => GlobalKey<NavigatorState>(debugLabel: 'main-branch-$index'),
  );

  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'main-navigation',
        builder: (context, state, navigationShell) => ResponsiveShell(
          navigationShell: navigationShell,
          onDismissTransientRoutes: () {
            branchNavigatorKeys[navigationShell.currentIndex].currentState
                ?.popUntil((route) => route is! PopupRoute<dynamic>);
          },
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[0],
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => _topLevelTabPage(
                  state,
                  const _SubjectScopedContent(
                    scope: 'home',
                    child: HomeScreen(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[1],
            initialLocation: '/learn',
            routes: [
              GoRoute(
                path: '/learn',
                pageBuilder: (context, state) => _topLevelTabPage(
                  state,
                  const _SubjectScopedContent(
                    scope: 'learn',
                    child: LearningHubScreen(),
                  ),
                ),
              ),
              GoRoute(
                path: '/path',
                builder: (context, state) => const _SubjectScopedContent(
                  scope: 'path',
                  child: CoursePathScreen(),
                ),
              ),
              GoRoute(
                path: '/missions',
                builder: (context, state) => const _SubjectScopedContent(
                  scope: 'missions',
                  child: MissionCatalogScreen(),
                ),
              ),
              GoRoute(
                path: '/unit/:unitIndex',
                builder: (context, state) => _SubjectScopedContent(
                  scope: 'unit-guide',
                  child: UnitGuideScreen(
                    unitIndex:
                        int.tryParse(state.pathParameters['unitIndex'] ?? '') ??
                        -1,
                  ),
                ),
              ),
              GoRoute(
                path: '/notes/:unitIndex',
                builder: (context, state) => _SubjectScopedContent(
                  scope: 'unit-notes',
                  child: UnitNotesScreen(
                    unitIndex:
                        int.tryParse(state.pathParameters['unitIndex'] ?? '') ??
                        -1,
                  ),
                ),
              ),
              GoRoute(
                path: '/session-builder',
                builder: (context, state) => const _SubjectScopedContent(
                  scope: 'session-builder',
                  child: SessionBuilderScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[2],
            initialLocation: '/library',
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) => _topLevelTabPage(
                  state,
                  LibraryScreen(
                    initialSubjectId: state.uri.queryParameters['subject'],
                    initialGroup: state.uri.queryParameters['group'],
                    initialQuery: state.uri.queryParameters['q'],
                  ),
                ),
              ),
              GoRoute(
                path: '/library/groups',
                builder: (context, state) => const GroupOrganizerScreen(),
              ),
              GoRoute(
                path: '/library/quality',
                builder: (context, state) => const ContentQualityScreen(),
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
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[3],
            initialLocation: '/stats',
            routes: [
              GoRoute(
                path: '/stats',
                pageBuilder: (context, state) => _topLevelTabPage(
                  state,
                  const _SubjectScopedContent(
                    scope: 'stats',
                    child: StatsScreen(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[4],
            initialLocation: '/settings',
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => _topLevelTabPage(
                  state,
                  SettingsScreen(
                    initialFocus: state.uri.queryParameters['focus'],
                  ),
                ),
              ),
              GoRoute(
                path: '/settings/personalize',
                builder: (context, state) => const PersonalizationScreen(),
              ),
              GoRoute(
                path: '/settings/data-health',
                builder: (context, state) => const DataHealthScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/mission/:unitIndex',
        builder: (context, state) => MissionPracticeScreen(
          unitIndex:
              int.tryParse(state.pathParameters['unitIndex'] ?? '') ?? -1,
        ),
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
          final requestedLimit = int.tryParse(
            state.uri.queryParameters['limit'] ?? '',
          );
          final queuePriority = StudyQueuePriority.values.firstWhere(
            (value) => value.name == state.uri.queryParameters['queuePriority'],
            orElse: () => StudyQueuePriority.dueFirst,
          );
          final historyFilter = StudyHistoryFilter.values.firstWhere(
            (value) => value.name == state.uri.queryParameters['historyFilter'],
            orElse: () => StudyHistoryFilter.all,
          );
          final subjectScope =
              activeSession?.courseId ??
              ref.read(appControllerProvider).activeCourseId;
          final playlistActivityIds =
              (state.uri.queryParameters['playlist'] ?? '')
                  .split(',')
                  .where(isPlaylistCompatiblePracticeActivity)
                  .take(5)
                  .toList(growable: false);
          return StudyScreen(
            key: ValueKey(
              'study:$subjectScope:${activeSession?.sessionId ?? 'new'}:'
              '${state.uri}',
            ),
            mode: mode,
            unitIndex: unitIndex,
            itemLimit: requestedLimit
                ?.clamp(
                  StudyLimits.minSessionItems,
                  StudyLimits.maxSessionItems,
                )
                .toInt(),
            queuePriority: queuePriority,
            historyFilter: historyFilter,
            resume: activeSession != null,
            customPlan: state.uri.queryParameters['custom'] == 'true',
            examMode:
                activeSession?.runtimeOptions.examSetupPending == true ||
                activeSession?.runtimeOptions.practiceActivityId ==
                    'exam-simulator' ||
                activeSession?.runtimeOptions.examConfiguration != null ||
                state.uri.queryParameters['exam'] == 'true',
            startMatchSprint: state.uri.queryParameters['match'] == 'true',
            practiceActivityId:
                activeSession?.runtimeOptions.practiceActivityId ??
                state.uri.queryParameters['practiceActivityId'],
            playlistActivityIds: playlistActivityIds,
            playlistIndex:
                int.tryParse(
                  state.uri.queryParameters['playlistIndex'] ?? '',
                ) ??
                0,
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
          final subjectId = ref.read(appControllerProvider).activeSubjectId;
          return FlashcardScreen(
            key: ValueKey('cards:$subjectId:${state.uri}'),
            kind: kind,
            unitIndex: unitIndex,
            customPlan: state.uri.queryParameters['custom'] == 'true',
          );
        },
      ),
      GoRoute(
        path: '/pronunciation',
        builder: (context, state) {
          final subjectId = ref.read(appControllerProvider).activeSubjectId;
          return PronunciationScreen(
            key: ValueKey('pronunciation:$subjectId:${state.uri}'),
            unitIndex: int.tryParse(state.uri.queryParameters['unit'] ?? ''),
            customPlan: state.uri.queryParameters['custom'] == 'true',
          );
        },
      ),
    ],
  );
});
