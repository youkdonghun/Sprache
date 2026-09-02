import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
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

  testWidgets(
    'session manager keeps contextual keyboard help off the app bar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await _pumpHarness(tester);
      try {
        expect(find.byKey(const Key('open-study-keyboard-help')), findsNothing);

        await tester.tap(find.byKey(const Key('open-session-management')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('open-session-keyboard-help')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('open-session-keyboard-help')));
        await tester.pumpAndSettle();
        expect(find.text('퀴즈 단축키'), findsOneWidget);
        expect(find.text('Ctrl+/'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('starting another study never silently replaces a session', (
    tester,
  ) async {
    final container = await _pumpHarness(tester);
    try {
      final original = container.read(
        appControllerProvider.select((state) => state.activeStudySession),
      );
      expect(original, isNotNull);

      container.read(appRouterProvider).go('/learn');
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/study?mode=production');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-session-conflict-dialog')),
        findsOneWidget,
      );
      expect(
        container.read(appControllerProvider).activeStudySession?.sessionId,
        original?.sessionId,
      );

      await tester.tap(find.byKey(const Key('cancel-new-session')));
      await tester.pumpAndSettle();
      expect(find.text('영어 학습실'), findsOneWidget);
      expect(
        container.read(appControllerProvider).activeStudySession?.sessionId,
        original?.sessionId,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a quiz from another language does not block the new language', (
    tester,
  ) async {
    final container = await _pumpHarness(tester);
    try {
      final controller = container.read(appControllerProvider.notifier);
      final englishSession = container
          .read(appControllerProvider)
          .activeStudySession;
      expect(englishSession, isNotNull);

      container.read(appRouterProvider).go('/learn');
      await tester.pumpAndSettle();
      controller.selectLanguage(LanguageTag.japanese);
      await tester.pumpAndSettle();
      final japaneseCourseId = container
          .read(appControllerProvider)
          .activeCourseId;
      expect(japaneseCourseId, isNot(englishSession?.courseId));

      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('active-session-conflict-dialog')),
        findsNothing,
      );
      final japaneseSession = container
          .read(appControllerProvider)
          .activeStudySession;
      expect(japaneseSession, isNotNull);
      expect(japaneseSession?.courseId, japaneseCourseId);
      expect(japaneseSession?.sessionId, isNot(englishSession?.sessionId));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('replacing a session requires an explicit destructive choice', (
    tester,
  ) async {
    final container = await _pumpHarness(tester);
    try {
      final originalId = container
          .read(appControllerProvider)
          .activeStudySession
          ?.sessionId;

      container.read(appRouterProvider).go('/learn');
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/study?mode=production');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replace-active-session')));
      await tester.pumpAndSettle();

      final replacement = container
          .read(appControllerProvider)
          .activeStudySession;
      expect(replacement, isNotNull);
      expect(replacement?.sessionId, isNot(originalId));
      expect(replacement?.mode, StudyMode.production);
      expect(replacement?.completedCount, 0);
      expect(find.byType(StudyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a stale screen cannot mutate or clear a replacement session', (
    tester,
  ) async {
    final container = await _pumpHarness(tester);
    try {
      final controller = container.read(appControllerProvider.notifier);
      final original = container.read(appControllerProvider).activeStudySession;
      expect(original, isNotNull);

      final replacement = controller.beginActiveStudySession(
        sessionId: 'remote-replacement',
        mode: StudyMode.production,
        unitIndex: null,
        itemIds: original!.itemIds,
        startedAt: DateTime.utc(2026, 7, 28, 12, 5),
      );

      final staleUpdate = controller.updateActiveStudySession(
        itemIds: original.itemIds,
        currentIndex: 1,
        correctCount: 99,
        wrongCount: 0,
        earnedXp: 990,
        updatedAt: DateTime.utc(2026, 7, 28, 12, 6),
        expectedSessionId: original.sessionId,
      );
      final staleClear = controller.clearActiveStudySession(
        expectedSessionId: original.sessionId,
      );

      expect(staleUpdate, isNull);
      expect(staleClear, isFalse);
      expect(
        container.read(appControllerProvider).activeStudySession?.sessionId,
        replacement.sessionId,
      );
      expect(
        container.read(appControllerProvider).activeStudySession?.correctCount,
        0,
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
