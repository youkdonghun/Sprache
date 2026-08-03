import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'report exposes range, trends, skills, calendar and hard review',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      );
      await store.saveStudySession(
        StudySessionSummary(
          sessionId: 'insight-session',
          courseId: 'ko-en',
          startedAt: DateTime.utc(2026, 8, 1, 9),
          endedAt: DateTime.utc(2026, 8, 1, 9, 12),
          correctCount: 8,
          wrongCount: 2,
          earnedXp: 24,
          mode: StudyMode.production,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            appClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 8, 2, 12),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      final controller = container.read(appControllerProvider.notifier);
      final hardItem = controller.selectedItems.first;
      controller.recordAnswer(
        item: hardItem,
        correct: false,
        studiedAt: DateTime.utc(2026, 8, 2, 10),
        exerciseType: 'production',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('기록').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-range-filter')), findsOneWidget);
      expect(find.byKey(const Key('learning-trend-card')), findsOneWidget);
      expect(
        find.byKey(const Key('accessible-study-calendar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('skill-insights-card')), findsOneWidget);
      expect(find.byKey(const Key('hardest-items-card')), findsOneWidget);
      expect(find.byKey(const Key('export-private-summary')), findsOneWidget);
      expect(find.text('24 XP · 80% (10)'), findsOneWidget);

      await tester.tap(find.text('7일'));
      await tester.pumpAndSettle();
      expect(find.text('7일 학습 흐름'), findsOneWidget);

    final review = find.byKey(Key('review-hard-item-${hardItem.id}'));
    tester.widget<TextButton>(review).onPressed!();
    await tester.pumpAndSettle();
      expect(controller.activeSessionPlan.selectedItemIds, {hardItem.id});
      expect(tester.takeException(), isNull);
    },
  );
}
