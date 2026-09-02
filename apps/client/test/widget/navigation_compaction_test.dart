import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/smart_collection.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/course_path_screen.dart';
import 'package:sprache/src/screens/learning_hub_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/course_picker.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {MemoryStudyStore? store}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(store ?? MemoryStudyStore()),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAllGames(WidgetTester tester) async {
    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
  }

  testWidgets('active tab reselect returns its branch to the root screen', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    container.read(appRouterProvider).go('/path');
    await tester.pumpAndSettle();
    expect(find.byType(CoursePathScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    expect(find.byType(CoursePathScreen), findsNothing);
    expect(find.byType(LearningHubScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets(
    'switching tabs resets the target branch and shows current provider state',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/path');
      await tester.pumpAndSettle();
      expect(find.byType(CoursePathScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();
      container
          .read(appControllerProvider.notifier)
          .selectSubject('language:ja');
      await tester.pump();

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();

      expect(find.byType(CoursePathScreen), findsNothing);
      expect(find.byType(LearningHubScreen), findsOneWidget);
      expect(find.text('일본어 학습'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the compact shell subject switcher is shared by every tab', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.byKey(const Key('shell-mobile-subject-switcher')),
      findsOneWidget,
    );
    expect(find.byType(CoursePicker), findsNothing);

    for (final destination in const ['learn', 'library', 'stats', 'settings']) {
      await tester.tap(find.byKey(Key('nav-$destination')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('shell-mobile-subject-switcher')),
        findsOneWidget,
      );
      if (destination == 'learn') {
        expect(find.byType(CoursePicker), findsNothing);
      }
    }
  });

  testWidgets('tab switch dismisses a branch sheet without resurrecting it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();
    await openAllGames(tester);
    await tester.ensureVisible(find.byKey(const Key('quick-practice-quiz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-practice-quiz')));
    await tester.pumpAndSettle();
    expect(find.text('세션 길이'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-library')));
    await tester.pumpAndSettle();
    expect(find.text('세션 길이'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();
    expect(find.byType(LearningHubScreen), findsOneWidget);
    expect(find.text('세션 길이'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an active session is the only home primary learning action', (
    tester,
  ) async {
    final items = sampleContent
        .where((item) => item.learningLanguage.code == 'en')
        .take(5)
        .toList(growable: false);
    final startedAt = DateTime(2026, 7, 30, 8);
    await pumpApp(
      tester,
      store: MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
        activeStudySession: ActiveStudySession(
          sessionId: 'single-primary-action',
          courseId: 'ko-en',
          mode: StudyMode.meaning,
          itemIds: items.map((item) => item.id).toList(growable: false),
          currentIndex: 1,
          correctCount: 1,
          wrongCount: 0,
          earnedXp: 10,
          startedAt: startedAt,
          updatedAt: startedAt,
        ),
      ),
    );

    expect(find.byKey(const Key('resume-study-card')), findsOneWidget);
    expect(find.byKey(const Key('home-next-study-card')), findsNothing);
    expect(find.byKey(const Key('home-primary-study-button')), findsOneWidget);
    expect(find.byKey(const Key('resume-active-session')), findsOneWidget);
  });

  testWidgets('due review takes priority over the recommended next lesson', (
    tester,
  ) async {
    await pumpApp(
      tester,
      store: MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    final controller = container.read(appControllerProvider.notifier);
    final item = controller.selectedItems.first;
    controller.recordAnswer(
      item: item,
      correct: false,
      studiedAt: DateTime(2020, 1, 1),
      exerciseType: 'navigation-compaction-test',
      rating: ReviewRating.again,
    );
    await tester.pumpAndSettle();

    expect(find.text('복습할 표현 1개'), findsOneWidget);
    expect(find.text('복습 시작'), findsOneWidget);
    expect(find.byKey(const Key('home-primary-study-button')), findsOneWidget);
  });

  testWidgets('learning hub keeps every practice method visible', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 추천 시작'), findsNothing);
    expect(find.byKey(const Key('personalized-practice-hub')), findsOneWidget);
    expect(find.text('오늘의 추천 학습'), findsOneWidget);
    expect(find.byKey(const Key('open-session-builder')), findsOneWidget);
    expect(find.byKey(const Key('practice-category-퀴즈')), findsNothing);

    await openAllGames(tester);
    expect(find.byKey(const Key('personalized-practice-hub')), findsNothing);
    expect(find.byKey(const Key('practice-category-퀴즈')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-혼합 퀴즈')), findsOneWidget);
    expect(find.byKey(const Key('practice-category-퀴즈')), findsOneWidget);
    expect(find.byKey(const Key('practice-category-암기')), findsOneWidget);
    expect(find.byKey(const Key('practice-category-실전')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-단어 카드')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-발음 따라하기')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('practice-activity-혼합 퀴즈'))).width,
      lessThan(200),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('practice hub explains why overdue review is ranked first', (
    tester,
  ) async {
    await pumpApp(
      tester,
      store: MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    final controller = container.read(appControllerProvider.notifier);
    controller.recordAnswer(
      item: controller.selectedItems.first,
      correct: false,
      studiedAt: DateTime(2020, 1, 1),
      exerciseType: 'practice-hub-ranking-test',
      rating: ReviewRating.again,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    expect(find.text('오늘 복습'), findsOneWidget);
    expect(find.text('복습 기한이 된 표현 1개'), findsOneWidget);
    expect(find.text('지금 먼저 하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pinned smart collection opens from the learning hub', (
    tester,
  ) async {
    final item = sampleContent.firstWhere(
      (value) => value.learningLanguage.code == 'en',
    );
    await pumpApp(
      tester,
      store: MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          smartCollections: [
            SmartCollectionDefinition(
              id: 'pinned-commute',
              subjectId: 'language:en',
              name: '출근 복습',
              query: item.text,
              pinned: true,
              updatedAt: DateTime(2026, 7, 31),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('learning-hub-pinned-collections')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pinned-collection-pinned-commute')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-subject-key')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    expect(
      container.read(appControllerProvider).preferences.sessionPlan.title,
      '출근 복습',
    );
    expect(
      container
          .read(appControllerProvider)
          .preferences
          .sessionPlan
          .selectedItemIds,
      contains(item.id),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pinned smart collection is available safely from home', (
    tester,
  ) async {
    final item = sampleContent.firstWhere(
      (value) => value.learningLanguage.code == 'en',
    );
    await pumpApp(
      tester,
      store: MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          sessionPlan: const StudySessionPlan(
            subjectId: 'language:en',
            difficulty: StudyDifficulty.weak,
            historyFilter: StudyHistoryFilter.wrongOnly,
          ),
          smartCollections: [
            SmartCollectionDefinition(
              id: 'home-pinned-commute',
              subjectId: 'language:en',
              name: '아침 핵심',
              query: item.text,
              pinned: true,
              updatedAt: DateTime(2026, 7, 31),
            ),
            SmartCollectionDefinition(
              id: 'home-pinned-empty',
              subjectId: 'language:en',
              name: '빈 조건',
              query: 'definitely-no-matching-sprache-item',
              pinned: true,
              updatedAt: DateTime(2026, 7, 31, 1),
            ),
          ],
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const Key('home-simple-details-toggle')),
    );
    await tester.tap(find.byKey(const Key('home-simple-details-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-pinned-collections')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('manage-home-pinned-collections')),
          )
          .tooltip,
      '고정 컬렉션 관리',
    );
    expect(
      tester
          .getSize(find.byKey(const Key('manage-home-pinned-collections')))
          .height,
      greaterThanOrEqualTo(44),
    );
    final emptyChip = tester.widget<ActionChip>(
      find.byKey(const Key('home-pinned-collection-home-pinned-empty')),
    );
    expect(emptyChip.onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('home-pinned-collection-home-pinned-commute')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    final plan = container.read(appControllerProvider).preferences.sessionPlan;
    expect(plan.title, '아침 핵심');
    expect(plan.selectedItemIds, contains(item.id));
    expect(plan.difficulty, StudyDifficulty.all);
    expect(plan.historyFilter, StudyHistoryFilter.all);
    expect(find.byKey(const Key('session-subject-key')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning hub reopens the active subject recent configuration', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    final items = sampleContent
        .where((item) => item.learningLanguage.code == 'en')
        .take(4)
        .toList(growable: false);
    await store.saveStudySession(
      StudySessionSummary(
        sessionId: 'recent-learning-hub',
        courseId: 'ko-en',
        startedAt: DateTime(2026, 7, 30, 9),
        endedAt: DateTime(2026, 7, 30, 9, 5),
        correctCount: 3,
        wrongCount: 1,
        earnedXp: 30,
        itemIds: items.map((item) => item.id).toList(growable: false),
        finalCorrectItemIds: items.take(3).map((item) => item.id).toSet(),
        wrongItemIds: {items.last.id},
        mode: StudyMode.words,
        historyFilter: StudyHistoryFilter.excludeCorrect,
      ),
    );
    await pumpApp(tester, store: store);
    await tester.tap(find.byKey(const Key('nav-learn')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recent-subject-session-card')),
      findsOneWidget,
    );
    expect(find.textContaining('단어 연습 · 맞힌 항목 제외'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reopen-recent-subject-session')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    final plan = container.read(appControllerProvider).preferences.sessionPlan;
    expect(plan.mode, StudyMode.words);
    expect(plan.historyFilter, StudyHistoryFilter.excludeCorrect);
    expect(plan.selectedItemIds, items.map((item) => item.id).toSet());
  });
}
