import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('home starts a two-minute weak and review session', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final english = sampleContent
        .where((item) => item.effectiveSubjectId == 'language:en')
        .take(5)
        .toList();
    final now = DateTime.now().toUtc();
    final profile = StoredProfile(
      selectedLanguage: LanguageTag.english,
      totalXp: 10,
      streakDays: 1,
      dailyXp: 10,
      badges: const {},
      driveConnected: false,
      progress: {
        for (final (index, item) in english.indexed)
          item.id: ProgressRecord(
            itemId: item.id,
            status: LearningStatus.review,
            correctCount: index + 1,
            wrongCount: 3,
            nextReviewAt: now.subtract(const Duration(minutes: 1)),
          ),
      },
    );
    final store = MemoryStudyStore(
      profile: profile,
      preferences: const StudyPreferences(onboardingCompleted: true),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('home-simple-details-toggle')),
      );
      await tester.tap(find.byKey(const Key('home-simple-details-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('two-minute-study-card')),
      );
      expect(find.byKey(const Key('two-minute-study-card')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('schedule-two-minute-study')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(const Key('start-two-minute-study'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(const Key('two-minute-study-card'))).height,
        lessThanOrEqualTo(60),
      );
      await tester.tap(find.byKey(const Key('start-two-minute-study')));
      await tester.pumpAndSettle();

      expect(store.savedPreferences.sessionPlan.timeBudgetMinutes, 2);
      expect(
        store.savedPreferences.sessionPlan.itemLimit,
        inInclusiveRange(3, 5),
      );
      expect(store.savedPreferences.sessionPlan.selectedItemIds, hasLength(5));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('saved routine exposes explicit order controls', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final now = DateTime.now().toUtc();
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        onboardingCompleted: true,
        savedSessionPlans: [
          StudySessionPlan(
            planId: 'routine-a',
            subjectId: 'language:en',
            title: '단어',
            routineName: '출근 루틴',
            routineWeekdays: const {1, 3, 5},
            routineMinuteOfDay: 480,
            routineOrder: 0,
            updatedAt: now,
          ),
          StudySessionPlan(
            planId: 'routine-b',
            subjectId: 'language:en',
            title: '문장',
            routineName: '출근 루틴',
            routineWeekdays: const {1, 3, 5},
            routineMinuteOfDay: 480,
            routineOrder: 1,
            updatedAt: now,
          ),
        ],
      ),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      final advanced = find.byKey(const Key('toggle-advanced-practice'));
      await tester.ensureVisible(advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('routine-label-routine-a')), findsOneWidget);
      await tester.tap(find.byKey(const Key('saved-plan-actions-routine-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('routine-later-routine-a')));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        store.savedPreferences.savedSessionPlans
            .firstWhere((plan) => plan.planId == 'routine-a')
            .routineOrder,
        1,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
