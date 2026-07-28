import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('session manager creates remaining and restart lineage', (
    tester,
  ) async {
    final container = await _pumpHarness(tester);
    try {
      final root = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(root, isNotNull);

      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('branch-wrong-session')), findsOneWidget);
      expect(find.byKey(const Key('branch-remaining-session')), findsOneWidget);

      await tester.tap(find.byKey(const Key('branch-remaining-session')));
      await tester.pumpAndSettle();

      final branch = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(branch?.origin, StudySessionOrigin.remaining);
      expect(branch?.generation, 1);
      expect(branch?.rootSessionId, root?.sessionId);
      expect(branch?.parentSessionId, root?.sessionId);

      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restart-study-session')));
      await tester.pumpAndSettle();

      final restarted = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(restarted?.origin, StudySessionOrigin.restarted);
      expect(restarted?.generation, 2);
      expect(restarted?.rootSessionId, root?.sessionId);
      expect(restarted?.parentSessionId, branch?.sessionId);
      expect(
        restarted?.journey.last.action,
        StudySessionJourneyAction.restarted,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('pause and resume update lifecycle state', (tester) async {
    final container = await _pumpHarness(tester);
    try {
      await tester.tap(find.byKey(const Key('pause-study-session')));
      await tester.pumpAndSettle();

      expect(find.byType(StudyScreen), findsNothing);
      final paused = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(paused?.phase, ActiveStudySessionPhase.paused);
      expect(paused?.pauseCount, 1);

      container.read(appRouterProvider).go('/study?resume=true');
      await tester.pumpAndSettle();

      final resumed = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(resumed?.phase, ActiveStudySessionPhase.active);
      expect(resumed?.resumeCount, 1);
      expect(
        resumed?.journey.map((event) => event.action),
        containsAllInOrder([
          StudySessionJourneyAction.started,
          StudySessionJourneyAction.paused,
          StudySessionJourneyAction.resumed,
        ]),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<ProviderContainer> _pumpHarness(WidgetTester tester) async {
  final store = MemoryStudyStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appClockProvider.overrideWithValue(() => DateTime.utc(2026, 7, 28, 12)),
      ],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SpracheApp)),
  );
  container.read(appRouterProvider).go('/study?mode=meaning');
  await tester.pumpAndSettle();
  expect(find.byType(StudyScreen), findsOneWidget);
  return container;
}
