import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/mission_script.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/course_path_screen.dart';
import 'package:sprache/src/screens/mission_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('course and mission recommendations are not repeated in lists', (
    tester,
  ) async {
    await _pumpScreen(tester, const CoursePathScreen());

    expect(find.byKey(const Key('continue-course-lesson')), findsOneWidget);
    expect(find.byKey(const Key('course-unit-0')), findsNothing);
    expect(find.byKey(const Key('course-unit-1')), findsOneWidget);
    expect(find.text('입문 코스 · 6개 단원'), findsOneWidget);

    await _pumpScreen(tester, const MissionCatalogScreen());

    expect(find.byKey(const Key('start-recommended-mission')), findsOneWidget);
    expect(find.text(missionDefinitions.first.title), findsOneWidget);
    expect(find.byKey(const Key('mission-card-0')), findsNothing);
    expect(find.byKey(const Key('mission-card-1')), findsOneWidget);
  });

  testWidgets('mission can finish through the explicit coached branch', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpScreen(tester, const MissionPracticeScreen(unitIndex: 0));

      var sceneCount = 0;
      while (find.byKey(const Key('mission-reveal')).evaluate().isNotEmpty) {
        expect(sceneCount, lessThan(10));
        final coach = find.byKey(const Key('mission-reveal'));
        await tester.ensureVisible(coach);
        await tester.tap(coach);
        await tester.pumpAndSettle();
        expect(find.text('힌트를 사용했어요'), findsOneWidget);

        final next = find.byKey(const Key('mission-next-phrase'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        sceneCount++;
      }

      expect(sceneCount, greaterThanOrEqualTo(3));
      expect(find.text('도움을 활용해 목표 달성'), findsOneWidget);
      expect(find.textContaining('$sceneCount개 장면에서 단서'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });

  testWidgets('mission restores its exact scene and branch after recreation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final checkpoint = MissionProgressCheckpoint(
      courseId: 'ko-en',
      unitIndex: 0,
      phraseIndex: 1,
      sceneId: 'unit-0-scene-0-coached',
      coachedTurns: 1,
      decision: MissionCheckpointDecision.coachedHelp,
      updatedAt: DateTime.utc(2026, 8, 3, 11),
    );
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        missionProgressCheckpoints: {checkpoint.storageKey: checkpoint},
      ),
    );
    try {
      await _pumpScreenWithStore(
        tester,
        const MissionPracticeScreen(unitIndex: 0),
        store,
      );

      expect(find.text('보강 · 표현 1 / 3'), findsOneWidget);
      expect(find.byKey(const Key('mission-branch-feedback')), findsOneWidget);
      final next = find.byKey(const Key('mission-next-phrase'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        store.savedPreferences.missionCheckpointFor('ko-en', 0)?.phraseIndex,
        2,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpScreenWithStore(
        tester,
        const MissionPracticeScreen(unitIndex: 0),
        store,
      );

      expect(find.text('표현 2 / 3'), findsOneWidget);
      expect(find.byKey(const Key('mission-branch-feedback')), findsNothing);
      var turns = 0;
      while (find.byKey(const Key('mission-reveal')).evaluate().isNotEmpty) {
        expect(turns++, lessThan(10));
        final coach = find.byKey(const Key('mission-reveal'));
        await tester.ensureVisible(coach);
        await tester.tap(coach);
        await tester.pumpAndSettle();
        final advance = find.byKey(const Key('mission-next-phrase'));
        await tester.ensureVisible(advance);
        await tester.tap(advance);
        await tester.pumpAndSettle();
      }

      expect(find.text('실전 미션 완료'), findsOneWidget);
      expect(store.savedPreferences.missionCheckpointFor('ko-en', 0), isNull);
      expect(store.savedPreferences.hasCompletedMission('ko-en', 0), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await _pumpScreenWithStore(tester, screen, MemoryStudyStore());
}

Future<void> _pumpScreenWithStore(
  WidgetTester tester,
  Widget screen,
  MemoryStudyStore store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}
