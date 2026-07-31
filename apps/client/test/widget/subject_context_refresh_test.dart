import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/flashcard_screen.dart';
import 'package:sprache/src/screens/learning_hub_screen.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('home only shows the active subject session', (tester) async {
    final startedAt = DateTime.utc(2026, 7, 31, 9);
    final englishItems = sampleContent
        .where((item) => item.courseId == 'ko-en')
        .take(3)
        .toList(growable: false);
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:ja',
      ),
      activeStudySession: ActiveStudySession(
        sessionId: 'english-paused-session',
        courseId: 'ko-en',
        mode: StudyMode.meaning,
        itemIds: englishItems.map((item) => item.id).toList(growable: false),
        currentIndex: 1,
        correctCount: 1,
        wrongCount: 0,
        earnedXp: 10,
        startedAt: startedAt,
        updatedAt: startedAt,
      ),
    );
    final container = await _pumpApp(tester, store);

    expect(find.byKey(const Key('resume-study-card')), findsNothing);
    expect(find.textContaining('일본어'), findsWidgets);

    container.read(appControllerProvider.notifier).selectSubject('language:en');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resume-study-card')), findsOneWidget);
    expect(find.text('영어'), findsWidgets);
  });

  testWidgets('changing subject pauses the open quiz and refreshes the hub', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    final container = await _pumpApp(tester, store);
    container.read(appRouterProvider).go('/study?mode=meaning');
    await tester.pumpAndSettle();

    expect(find.byType(StudyScreen), findsOneWidget);
    final original = container.read(appControllerProvider).activeStudySession;
    expect(original?.courseId, 'ko-en');

    container.read(appControllerProvider.notifier).selectSubject('language:ja');
    await tester.pumpAndSettle();

    expect(find.byType(StudyScreen), findsNothing);
    expect(find.byType(LearningHubScreen), findsOneWidget);
    expect(find.textContaining('일본어 학습실'), findsOneWidget);
    final paused = container.read(appControllerProvider).activeStudySession;
    expect(paused?.sessionId, original?.sessionId);
    expect(paused?.courseId, 'ko-en');
    expect(paused?.phase, ActiveStudySessionPhase.paused);
  });

  testWidgets(
    'flashcard partial result stays assigned to its starting course',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      );
      final container = await _pumpApp(tester, store);
      container.read(appRouterProvider).go('/cards?kind=words');
      await tester.pumpAndSettle();

      expect(find.byType(FlashcardScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flashcard-remembered')));
      await tester.pump();

      container
          .read(appControllerProvider.notifier)
          .selectSubject('language:ja');
      await tester.pumpAndSettle();

      expect(find.byType(FlashcardScreen), findsNothing);
      expect(find.textContaining('일본어 학습실'), findsOneWidget);
      expect(store.savedSessions, hasLength(1));
      expect(store.savedSessions.single.courseId, 'ko-en');
      expect(store.savedSessions.single.correctCount, 1);
    },
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  MemoryStudyStore store,
) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SpracheApp)));
}
