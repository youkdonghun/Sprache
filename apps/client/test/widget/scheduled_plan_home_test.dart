import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'home opens only the active subject schedule and consumes it on start',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final now = DateTime(2026, 7, 29, 10);
      final english = StudySessionPlan(
        planId: 'english-morning',
        subjectId: 'language:en',
        title: '영어 출근 루틴',
        mode: StudyMode.listening,
        itemLimit: 5,
        scheduledAt: DateTime(2026, 7, 29, 11).toUtc(),
        updatedAt: DateTime(2026, 7, 28, 9).toUtc(),
      );
      final japanese = StudySessionPlan(
        planId: 'japanese-evening',
        subjectId: 'language:ja',
        title: '일본어 저녁 루틴',
        itemLimit: 5,
        scheduledAt: DateTime(2026, 7, 29, 20).toUtc(),
        updatedAt: DateTime(2026, 7, 28, 10).toUtc(),
      );
      final store = MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: 'language:en',
          sessionPlan: const StudySessionPlan(subjectId: 'language:en'),
          savedSessionPlans: [english, japanese],
        ),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              appClockProvider.overrideWithValue(() => now),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('home-next-study-card')), findsOneWidget);
        expect(find.byKey(const Key('home-scheduled-plans')), findsNothing);
        expect(find.text('영어 출근 루틴'), findsOneWidget);
        expect(find.text('일본어 저녁 루틴'), findsNothing);
        expect(find.textContaining('오늘 11:00'), findsOneWidget);

        await tester.tap(find.byKey(const Key('home-primary-study-button')));
        await tester.pumpAndSettle();

        expect(find.text('나만의 학습 세션'), findsOneWidget);
        expect(store.savedPreferences.sessionPlan.planId, 'english-morning');
        await tester.ensureVisible(
          find.byKey(const Key('session-start-bottom')),
        );
        await tester.tap(find.byKey(const Key('session-start-bottom')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pause-study-session')), findsOneWidget);
        expect(
          store.savedPreferences.savedSessionPlans
              .firstWhere((plan) => plan.planId == 'english-morning')
              .scheduledAt,
          isNull,
        );
        expect(
          store.savedPreferences.savedSessionPlans
              .firstWhere((plan) => plan.planId == 'japanese-evening')
              .scheduledAt,
          isNotNull,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        container.read(appRouterProvider).pop();
        await tester.pumpAndSettle();
        expect(find.text('나만의 학습 세션'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('exam schedule exposes compact home recovery actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final now = DateTime(2026, 7, 29, 10);
    final plan = StudySessionPlan(
      planId: 'exam-home-actions',
      subjectId: 'language:en',
      title: '시험 대비',
      itemLimit: 20,
      scheduledAt: now.toUtc(),
      examSchedule: ExamSchedule(
        targetDate: DateTime(2026, 8, 10).toUtc(),
        dailyCap: 20,
      ),
    );
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:en',
        sessionPlan: const StudySessionPlan(subjectId: 'language:en'),
        savedSessionPlans: [plan],
      ),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            appClockProvider.overrideWithValue(() => now),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('home-simple-details-toggle')),
      );
      await tester.tap(find.byKey(const Key('home-simple-details-toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home-schedule-quick-actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('schedule-snooze-ten-minutes')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('schedule-snooze-ten-minutes')));
      await tester.pumpAndSettle();

      final saved = store.savedPreferences.savedSessionPlans.singleWhere(
        (value) => value.planId == plan.planId,
      );
      expect(saved.scheduledAt, now.toUtc().add(const Duration(minutes: 10)));
      expect(find.text('10분 뒤에 다시 알려 드릴게요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final size in const [Size(520, 760), Size(1280, 800)]) {
    testWidgets('scheduled home card fits Windows ${size.width.toInt()}px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final now = DateTime(2026, 7, 29, 10);
      final store = MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: 'language:en',
          sessionPlan: const StudySessionPlan(subjectId: 'language:en'),
          savedSessionPlans: [
            StudySessionPlan(
              planId: 'windows-schedule',
              subjectId: 'language:en',
              title: '업무 중 5분 복습',
              itemLimit: 5,
              scheduledAt: DateTime(2026, 7, 29, 14).toUtc(),
            ),
          ],
        ),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              appClockProvider.overrideWithValue(() => now),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('home-next-study-card')), findsOneWidget);
        expect(find.byKey(const Key('home-scheduled-plans')), findsNothing);
        expect(find.text('업무 중 5분 복습'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}
