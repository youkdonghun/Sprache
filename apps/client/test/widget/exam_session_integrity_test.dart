import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/adaptive_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/quiz_session_support.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_runtime_modes.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets('router resumes a pre-configuration session as a pending exam', (
    tester,
  ) async {
    final startedAt = DateTime.utc(2026, 8, 3, 9);
    final active = ActiveStudySession.started(
      sessionId: 'pending-exam',
      courseId: LanguageTag.english.courseId,
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: const ['exam-a', 'exam-b'],
      startedAt: startedAt,
      runtimeOptions: const StudySessionRuntimeOptions(
        practiceActivityId: 'exam-simulator',
        examSetupPending: true,
      ),
    );
    final store = MemoryStudyStore(
      profile: _profile,
      preferences: _preferences,
      activeStudySession: active,
    );
    await store.saveCustomItems(_examItems.take(2).toList());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(store),
          appClockProvider.overrideWithValue(() => startedAt),
        ],
        child: const SpracheApp(),
      ),
    );
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    container.read(appRouterProvider).go('/study?resume=true');
    await _settle(tester);

    expect(find.byKey(const Key('exam-setup-dialog')), findsOneWidget);
    expect(
      container
          .read(appControllerProvider)
          .activeStudySession
          ?.runtimeOptions
          .examSetupPending,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumed exam report keeps earlier attempts and hides branches', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 3, 9);
    final active =
        ActiveStudySession.started(
          sessionId: 'resumed-exam',
          courseId: LanguageTag.english.courseId,
          mode: StudyMode.meaning,
          unitIndex: null,
          itemIds: const ['exam-a', 'exam-b'],
          startedAt: now.subtract(const Duration(minutes: 1)),
          runtimeOptions: StudySessionRuntimeOptions(
            examConfiguration: const ExamConfiguration(
              questionCount: 2,
              timeLimit: Duration(minutes: 10),
              passScore: 80,
            ),
            examDeadline: now.add(const Duration(minutes: 9)),
          ),
        ).copyWith(
          currentIndex: 1,
          wrongCount: 1,
          wrongItemIds: const {'exam-a'},
          attemptReviews: const [
            QuizAttemptReview(
              sequence: 1,
              itemId: 'exam-a',
              prompt: 'alpha',
              expectedAnswer: '알파',
              userAnswer: '오답',
              exerciseType: 'recognition',
              correct: false,
              rating: ReviewRating.again,
              usedHint: false,
            ),
          ],
        );
    final harness = await _pumpDirectStudy(
      tester,
      now: () => now,
      active: active,
      items: _examItems.take(2).toList(),
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        resume: true,
        examMode: true,
      ),
    );

    await tester.tap(find.text('베타'));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await _settle(tester);

    expect(find.byKey(const Key('exam-report-card')), findsOneWidget);
    expect(find.byKey(const Key('completion-action-wrong')), findsNothing);
    expect(find.byKey(const Key('completion-retry-mistakes')), findsNothing);
    expect(find.byKey(const Key('completion-replay-same')), findsNothing);
    expect(find.byKey(const Key('completion-replay-shuffled')), findsNothing);
    final reviewButton = find.byKey(const Key('completion-review-attempts'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await _settle(tester);
    expect(find.byKey(const Key('completion-attempt-1')), findsOneWidget);
    expect(find.byKey(const Key('completion-attempt-2')), findsOneWidget);
    expect(harness.store.savedEvents, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam deadline is recalculated only when the app resumes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 3, 9);
    await _pumpDirectStudy(
      tester,
      now: () => now,
      items: _examItems.take(1).toList(),
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 1,
        examMode: true,
      ),
    );
    await tester.tap(find.byKey(const Key('exam-time-limit-5')));
    await tester.tap(find.byKey(const Key('start-exam-mode')));
    await _settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 6));
    await tester.pump();
    expect(find.byKey(const Key('exam-report-card')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('exam-report-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('derived practice clears reviews and live difficulty history', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 3, 9);
    final metrics = [
      for (var index = 0; index < 3; index++)
        StudyAttemptMetric(
          itemId: _examItems[index].id,
          skill: StudySkill.meaning,
          errorType: StudyErrorType.meaningRecall,
          correct: false,
          responseTimeMs: 12000,
          recordedAt: now.subtract(Duration(seconds: 30 - index)),
        ),
    ];
    final reviews = [
      for (var index = 0; index < 3; index++)
        QuizAttemptReview(
          sequence: index + 1,
          itemId: _examItems[index].id,
          prompt: _examItems[index].text,
          expectedAnswer: _examItems[index].primaryTranslation,
          userAnswer: '오답',
          exerciseType: 'recognition',
          correct: false,
          rating: ReviewRating.again,
          usedHint: false,
        ),
    ];
    final active =
        ActiveStudySession.started(
          sessionId: 'completed-practice',
          courseId: LanguageTag.english.courseId,
          mode: StudyMode.meaning,
          unitIndex: null,
          itemIds: _examItems.map((item) => item.id).toList(),
          startedAt: now.subtract(const Duration(minutes: 2)),
        ).copyWith(
          currentIndex: 3,
          wrongCount: 3,
          wrongItemIds: _examItems.map((item) => item.id).toSet(),
          attemptMetrics: metrics,
          attemptReviews: reviews,
          updatedAt: now,
        );
    final harness = await _pumpDirectStudy(
      tester,
      now: () => now,
      active: active,
      items: _examItems,
      screen: const StudyScreen(mode: StudyMode.meaning, resume: true),
    );

    expect(find.byKey(const Key('completion-replay-same')), findsOneWidget);
    final replayButton = find.byKey(const Key('completion-replay-same'));
    await tester.ensureVisible(replayButton);
    await tester.tap(replayButton);
    await _settle(tester);

    final derived = harness.controller.state.activeStudySession;
    expect(derived?.attemptReviews, isEmpty);
    expect(derived?.attemptMetrics, isEmpty);
    expect(find.byKey(const Key('live-difficulty-indicator')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _profile = StoredProfile(
  selectedLanguage: LanguageTag.english,
  totalXp: 0,
  streakDays: 0,
  dailyXp: 0,
  badges: {},
  driveConnected: false,
  progress: {},
);

const _preferences = StudyPreferences(
  interaction: StudyInteractionPreferences(
    shuffleChoices: false,
    choiceLayout: StudyChoiceLayout.list,
  ),
);

const _examItems = [
  LearningItem(
    id: 'exam-a',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'alpha',
    translations: ['알파'],
    acceptedAnswers: ['알파'],
    source: ContentSource.userCreated,
  ),
  LearningItem(
    id: 'exam-b',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'beta',
    translations: ['베타'],
    acceptedAnswers: ['베타'],
    source: ContentSource.userCreated,
  ),
  LearningItem(
    id: 'exam-c',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: 'gamma',
    translations: ['감마'],
    acceptedAnswers: ['감마'],
    source: ContentSource.userCreated,
  ),
];

class _Harness {
  const _Harness(this.controller, this.store);

  final AppController controller;
  final MemoryStudyStore store;
}

Future<_Harness> _pumpDirectStudy(
  WidgetTester tester, {
  required DateTime Function() now,
  required List<LearningItem> items,
  required Widget screen,
  ActiveStudySession? active,
}) async {
  final store = MemoryStudyStore(
    profile: _profile,
    preferences: _preferences,
    activeStudySession: active,
  );
  await store.saveCustomItems(items);
  final controller = AppController(store);
  for (
    var attempt = 0;
    attempt < 100 && !controller.state.isHydrated;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 2));
  }
  expect(controller.state.isHydrated, isTrue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
        appClockProvider.overrideWithValue(now),
      ],
      child: MaterialApp(
        theme: AppTheme.mobileFor(
          _preferences.experience,
          brightness: Brightness.light,
        ),
        home: screen,
      ),
    ),
  );
  await _settle(tester);
  return _Harness(controller, store);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
