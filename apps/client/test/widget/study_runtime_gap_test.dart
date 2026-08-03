import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/adaptive_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/quiz_session_support.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_runtime_modes.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets('base-pack feedback creates and edits a local correction', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 1),
    );
    final prompt = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data!;
    final item = harness.controller.selectedItems.singleWhere(
      (candidate) => candidate.text == prompt,
    );

    await tester.tap(find.text(item.primaryTranslation));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-content-from-feedback')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const Key('base-content-correction-editor')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('base-correction-proposal')),
      '${item.text} → 새 제안',
    );
    await tester.enterText(
      find.byKey(const Key('base-correction-note')),
      '대표 뜻을 더 자연스럽게 다듬어야 합니다.',
    );
    await tester.tap(find.byKey(const Key('save-base-content-correction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final correction = harness.controller.contentCorrectionFor(item.id);
    expect(correction?.field, 'quizContent');
    expect(correction?.proposedValue, contains('새 제안'));

    await tester.tap(find.byKey(const Key('edit-content-from-feedback')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('base-correction-note')))
          .controller
          ?.text,
      contains('자연스럽게'),
    );
  });

  testWidgets('answer-result correction commits once and restore wins', (
    tester,
  ) async {
    final corrected = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 1),
    );

    await tester.tap(find.byKey(const Key('study-choice-1')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    expect(corrected.store.savedEvents, isEmpty);
    await tester.tap(find.byKey(const Key('correct-as-typo')));
    expect(corrected.store.savedEvents, isEmpty);
    await tester.tap(find.byKey(const Key('next-question-from-feedback')));
    await _settleBriefly(tester);
    expect(corrected.store.savedEvents, hasLength(1));
    expect(corrected.store.savedEvents.single.result, 'correct');

    final restored = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 1),
    );
    await tester.tap(find.byKey(const Key('study-choice-1')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('correct-as-typo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('restore-answer-result')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next-question-from-feedback')));
    await _settleBriefly(tester);
    expect(restored.store.savedEvents, hasLength(1));
    expect(restored.store.savedEvents.single.result, 'wrong');
  });

  testWidgets('recovery summary and persistent accessibility reach study UI', (
    tester,
  ) async {
    final profile = const AccessibilityInputProfile(
      largeRatingControls: true,
      cardScale: AccessibilityCardScale.extraLarge,
      disableTimedChallenges: true,
    ).remapShortcut(StudyShortcutAction.nextItem, StudyShortcutKey.keyR);
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        sessionPlan: StudySessionPlan(
          itemLimit: 2,
          backlogRecovery: BacklogRecoverySettings(
            enabled: true,
            dailyLimit: 5,
          ),
        ),
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      profile: profile,
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 2,
        customPlan: true,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('submit-study-answer'))).height,
      greaterThanOrEqualTo(64),
    );
    await tester.tap(find.byKey(const Key('open-session-management')));
    await _settleBriefly(tester);
    await tester.tap(find.byKey(const Key('start-match-sprint')));
    await _settleBriefly(tester);
    expect(find.byKey(const Key('match-mode-timed')), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await _settleBriefly(tester);

    for (var index = 0; index < 2; index++) {
      final prompt = tester
          .widget<Text>(find.byKey(const Key('study-question-prompt')))
          .data!;
      final item = harness.controller.selectedItems.singleWhere(
        (candidate) => candidate.text == prompt,
      );
      await tester.tap(find.text(item.primaryTranslation));
      await tester.tap(find.byKey(const Key('submit-study-answer')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await _settleBriefly(tester);
    }
    expect(harness.store.savedSessions.single.backlogRecovery, isTrue);
  });

  testWidgets('feedback keeps one strong primary action and groups utilities', (
    tester,
  ) async {
    await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 1),
    );

    await tester.tap(find.byKey(const Key('study-choice-0')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();

    final popup = find.byKey(const Key('study-feedback-popup'));
    expect(popup, findsOneWidget);
    expect(
      find.descendant(of: popup, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('feedback-more-actions')), findsOneWidget);
    expect(
      find.byKey(const Key('quick-add-from-study-feedback')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('feedback-more-actions')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-add-from-study-feedback')),
      findsOneWidget,
    );
  });

  testWidgets('completed catalog practice records today quest progress', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 1,
        practiceActivityId: 'meaning-choice',
      ),
    );
    final prompt = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data!;
    final item = harness.controller.selectedItems.singleWhere(
      (candidate) => candidate.text == prompt,
    );

    await tester.tap(find.text(item.primaryTranslation));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next-question-from-feedback')));
    await _settleBriefly(tester);

    final state = harness.controller.state;
    expect(
      state.preferences.interaction.practiceCatalog
          .completedDailyQuestActivityIds(
            day: DateTime.now(),
            subjectId: state.activeSubjectId,
            activityIds: const ['meaning-choice'],
          ),
      {'meaning-choice'},
    );
  });

  testWidgets('exam hides answer disclosure until its final report', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 2,
        examMode: true,
      ),
    );

    expect(find.byKey(const Key('exam-setup-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('exam-pass-score-90')));
    await tester.tap(find.byKey(const Key('start-exam-mode')));
    await _settleBriefly(tester);
    expect(find.byKey(const Key('study-time-estimate')), findsOneWidget);

    for (var index = 0; index < 2; index++) {
      final prompt = tester
          .widget<Text>(find.byKey(const Key('study-question-prompt')))
          .data!;
      final item = harness.controller.selectedItems.singleWhere(
        (candidate) => candidate.text == prompt,
      );
      await tester.tap(find.text(item.primaryTranslation));
      await tester.tap(find.byKey(const Key('submit-study-answer')));
      await _settleBriefly(tester);
      expect(find.byKey(const Key('study-feedback-popup')), findsNothing);
    }

    expect(find.byKey(const Key('exam-report-card')), findsOneWidget);
    expect(find.textContaining('통과 90점'), findsWidgets);
    expect(harness.store.savedEvents, isEmpty);
  });

  testWidgets('exam timer auto-submits unanswered questions', (tester) async {
    await _pumpStudy(
      tester,
      preferences: const StudyPreferences(),
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 1,
        examMode: true,
      ),
    );
    await tester.tap(find.byKey(const Key('exam-time-limit-5')));
    await tester.tap(find.byKey(const Key('start-exam-mode')));
    await _settleBriefly(tester);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(find.byKey(const Key('exam-report-card')), findsOneWidget);
    expect(find.textContaining('미응답 1'), findsWidgets);
    expect(find.textContaining('시간 종료'), findsOneWidget);
  });

  testWidgets('resumed exam restores its rules and skips setup', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    const items = [
      LearningItem(
        id: 'exam-resume-a',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'alpha',
        translations: ['알파'],
        acceptedAnswers: ['알파'],
      ),
      LearningItem(
        id: 'exam-resume-b',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'beta',
        translations: ['베타'],
        acceptedAnswers: ['베타'],
      ),
    ];
    final activeSession = ActiveStudySession.started(
      sessionId: 'exam-resume-session',
      courseId: LanguageTag.english.courseId,
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: items.map((item) => item.id).toList(),
      startedAt: now.subtract(const Duration(minutes: 1)),
      runtimeOptions: StudySessionRuntimeOptions(
        examConfiguration: const ExamConfiguration(
          questionCount: 2,
          timeLimit: Duration(minutes: 10),
          passScore: 90,
        ),
        examDeadline: now.add(const Duration(minutes: 9)),
      ),
    );

    await _pumpStudy(
      tester,
      preferences: const StudyPreferences(),
      customItems: items,
      activeStudySession: activeSession,
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        resume: true,
        examMode: true,
      ),
    );

    expect(find.byKey(const Key('exam-setup-dialog')), findsNothing);
    expect(find.byKey(const Key('compact-study-hud')), findsOneWidget);
    expect(find.byKey(const Key('study-question-prompt')), findsOneWidget);
    expect(find.textContaining('통과 90점'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('listening discrimination offers choices and a text fallback', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(
        mode: StudyMode.listening,
        itemLimit: 1,
        practiceActivityId: 'listening-discrimination',
      ),
    );

    expect(find.byKey(const Key('study-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('study-choice-2')), findsOneWidget);
    expect(find.byKey(const Key('listening-text-fallback')), findsOneWidget);
    expect(find.byKey(const Key('listening-choice-basis')), findsOneWidget);
    expect(
      harness.store.savedActiveStudySession?.runtimeOptions.practiceActivityId,
      'listening-discrimination',
    );
    await tester.tap(find.byKey(const Key('listening-text-fallback')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('study-question-prompt'))).data,
      startsWith('소리 대체 단서:'),
    );
  });

  testWidgets('session options can lock the live difficulty override', (
    tester,
  ) async {
    await _pumpStudy(
      tester,
      preferences: const StudyPreferences(),
      screen: const StudyScreen(mode: StudyMode.mixed, itemLimit: 3),
    );
    await tester.tap(find.byKey(const Key('open-session-management')));
    await _settleBriefly(tester);
    await tester.tap(find.byKey(const Key('study-session-options')));
    await _settleBriefly(tester);
    final challenge = find.byKey(const Key('session-difficulty-challenge'));
    await tester.ensureVisible(challenge);
    await tester.tap(challenge);
    final apply = find.byKey(const Key('apply-session-quiz-options'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await _settleBriefly(tester);

    expect(find.byKey(const Key('live-difficulty-indicator')), findsOneWidget);
    expect(find.text('난이도 고정 · 도전'), findsOneWidget);
  });

  testWidgets('rolling session mistakes lower the next-question difficulty', (
    tester,
  ) async {
    await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 3),
    );

    for (var index = 0; index < 3; index++) {
      await tester.ensureVisible(find.byKey(const Key('study-choice-1')));
      await tester.tap(find.byKey(const Key('study-choice-1')));
      await tester.tap(find.byKey(const Key('submit-study-answer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('next-question-from-feedback')));
      await _settleBriefly(tester);
    }

    expect(find.byKey(const Key('live-difficulty-indicator')), findsOneWidget);
    expect(find.text('난이도 자동 · 도움'), findsOneWidget);
  });

  testWidgets('match uses sequential traversal and records daily completion', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 2),
    );
    await tester.tap(find.byKey(const Key('open-session-management')));
    await _settleBriefly(tester);
    await tester.tap(find.byKey(const Key('start-match-sprint')));
    await _settleBriefly(tester);
    await tester.tap(find.byKey(const Key('begin-match-sprint')));
    await tester.pump();

    final learningButtons = find.byWidgetPredicate(
      (widget) =>
          widget is OutlinedButton &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('match-learning-'),
    );
    final learningKey =
        tester.widget<OutlinedButton>(learningButtons.first).key!
            as ValueKey<String>;
    final itemId = learningKey.value.substring('match-learning-'.length);
    final itemIds = [
      for (final element in learningButtons.evaluate())
        ((element.widget.key! as ValueKey<String>).value).substring(
          'match-learning-'.length,
        ),
    ];
    final learning = tester.widget<OutlinedButton>(
      find.byKey(Key('match-learning-$itemId')),
    );
    final meaningBefore = tester.widget<OutlinedButton>(
      find.byKey(Key('match-meaning-$itemId')),
    );
    expect(learning.onPressed, isNotNull);
    expect(meaningBefore.onPressed, isNull);

    await tester.tap(find.byKey(Key('match-learning-$itemId')));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(Key('match-meaning-$itemId')))
          .onPressed,
      isNotNull,
    );
    expect(find.byKey(const Key('match-sequence-status')), findsOneWidget);

    await tester.tap(find.byKey(Key('match-meaning-$itemId')));
    await tester.pump();
    for (final remainingId in itemIds.where((id) => id != itemId)) {
      await tester.tap(find.byKey(Key('match-learning-$remainingId')));
      await tester.pump();
      await tester.tap(find.byKey(Key('match-meaning-$remainingId')));
      await tester.pump();
    }
    expect(find.byKey(const Key('close-match-result')), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-match-result')));
    await _settleBriefly(tester);

    final state = harness.controller.state;
    expect(
      state.preferences.interaction.practiceCatalog
          .completedDailyQuestActivityIds(
            day: DateTime.now(),
            subjectId: state.activeSubjectId,
            activityIds: const ['match-sprint'],
          ),
      contains('match-sprint'),
    );
  });

  testWidgets('100 attempt completion review stays lazy and filterable', (
    tester,
  ) async {
    final attempts = [
      for (var index = 1; index <= 100; index++)
        QuizAttemptReview(
          sequence: index,
          itemId: 'item-$index',
          prompt: '문제 $index',
          expectedAnswer: '정답 $index',
          userAnswer: index.isEven ? '정답 $index' : '오답',
          exerciseType: 'recognition',
          correct: index.isEven,
          rating: index.isEven ? ReviewRating.good : ReviewRating.again,
          usedHint: index % 3 == 0,
        ),
    ];
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletionReviewSheet(
            attempts: attempts,
            onOpenItem: (value) => opened = value,
          ),
        ),
      ),
    );
    await _settleBriefly(tester);

    expect(find.byKey(const Key('completion-attempt-1')), findsOneWidget);
    expect(find.byKey(const Key('completion-attempt-100')), findsNothing);
    expect(
      find.byType(ExpansionTile).evaluate().length,
      lessThan(30),
      reason: 'ListView must not eagerly build all 100 review rows',
    );

    await tester.tap(find.byKey(const Key('completion-review-wrong-only')));
    await tester.pump();
    expect(find.text('2. 문제 2'), findsNothing);
    await tester.tap(find.byKey(const Key('completion-attempt-1')));
    await _settleBriefly(tester);
    await tester.tap(find.byKey(const Key('completion-edit-1')));
    expect(opened, 'item-1');
  });

  testWidgets('defer rotates the question without score or progress', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          answerDirection: StudyAnswerDirection.learningToMeaning,
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 3),
    );
    final promptBefore = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data!;
    final deferredItem = harness.controller.selectedItems.singleWhere(
      (candidate) => candidate.text == promptBefore,
    );
    final deferButton = tester.widget<TextButton>(
      find.byKey(const Key('defer-study-question')),
    );
    expect(deferButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('defer-study-question')));
    await _settleBriefly(tester);

    final promptAfter = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data!;
    expect(promptAfter, isNot(promptBefore));
    expect(find.text('이 문제를 감점 없이 세션 뒤로 미뤘습니다.'), findsOneWidget);
    expect(harness.store.savedEvents, isEmpty);
    expect(harness.controller.state.progress, isEmpty);
    expect(harness.controller.state.totalXp, 0);
    final active = harness.store.savedActiveStudySession;
    expect(active, isNotNull);
    expect(active!.currentIndex, 0);
    expect(active.correctCount, 0);
    expect(active.wrongCount, 0);
    expect(active.earnedXp, 0);
    expect(active.itemIds.last, deferredItem.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feedback quick add prefills the current item and example', (
    tester,
  ) async {
    const item = LearningItem(
      id: 'user-feedback-prefill',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'contextual',
      translations: ['문맥의'],
      acceptedAnswers: ['문맥의'],
      example: 'The clue is contextual.',
      exampleTranslation: '그 단서는 문맥에 따라 달라요.',
      capabilities: {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
      source: ContentSource.userCreated,
    );
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(
        sessionPlan: StudySessionPlan(
          mode: StudyMode.meaning,
          deck: StudyDeckScope.selected,
          selectedItemIds: {'user-feedback-prefill'},
          itemLimit: 1,
        ),
        interaction: StudyInteractionPreferences(
          answerDirection: StudyAnswerDirection.learningToMeaning,
          shuffleChoices: false,
          choiceLayout: StudyChoiceLayout.list,
        ),
      ),
      customItems: const [item],
      screen: const StudyScreen(
        mode: StudyMode.meaning,
        itemLimit: 1,
        customPlan: true,
      ),
    );
    expect(harness.controller.selectedItems, contains(item));
    expect(
      tester.widget<Text>(find.byKey(const Key('study-question-prompt'))).data,
      item.text,
    );

    await tester.tap(find.text(item.primaryTranslation));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('feedback-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-add-from-study-feedback')));
    await _settleBriefly(tester);

    expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('quick-content-text')))
          .controller
          ?.text,
      item.text,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('quick-content-meaning')))
          .controller
          ?.text,
      item.primaryTranslation,
    );

    final more = find.byKey(const Key('quick-content-more'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await _settleBriefly(tester);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('quick-content-example')))
          .controller
          ?.text,
      item.example,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('quick-content-example-meaning')),
          )
          .controller
          ?.text,
      item.exampleTranslation,
    );
    expect(tester.takeException(), isNull);
  });
}

class _StudyHarness {
  const _StudyHarness(this.controller, this.store);

  final AppController controller;
  final MemoryStudyStore store;
}

Future<_StudyHarness> _pumpStudy(
  WidgetTester tester, {
  required StudyPreferences preferences,
  required Widget screen,
  List<LearningItem> customItems = const [],
  ActiveStudySession? activeStudySession,
  AccessibilityInputProfile profile = const AccessibilityInputProfile(),
}) async {
  final store = MemoryStudyStore(
    profile: const StoredProfile(
      selectedLanguage: LanguageTag.english,
      totalXp: 0,
      streakDays: 0,
      dailyXp: 0,
      badges: {},
      driveConnected: false,
      progress: {},
    ),
    preferences: preferences,
    activeStudySession: activeStudySession,
  );
  if (customItems.isNotEmpty) await store.saveCustomItems(customItems);
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
      key: UniqueKey(),
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
        accessibilityInputProfileProvider.overrideWithValue(profile),
      ],
      child: MaterialApp(
        theme: AppTheme.mobileFor(
          preferences.experience,
          brightness: Brightness.light,
          accessibilityProfile: profile,
        ),
        home: screen,
      ),
    ),
  );
  await _settleBriefly(tester);
  return _StudyHarness(controller, store);
}

Future<void> _settleBriefly(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
