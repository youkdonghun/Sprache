import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_limits.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('hub tabs separate recommendations, games, and missions', (
    tester,
  ) async {
    await _pumpPracticeHub(tester, openGames: false);

    expect(find.byKey(const Key('practice-hub-tabs')), findsOneWidget);
    expect(find.byKey(const Key('personalized-practice-hub')), findsOneWidget);
    expect(find.byKey(const Key('practice-game-search')), findsNothing);

    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personalized-practice-hub')), findsNothing);
    expect(find.byKey(const Key('practice-game-search')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-시험 시뮬레이터')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-소리 구별')), findsOneWidget);

    await tester.tap(find.text('미션'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-game-search')), findsNothing);
    expect(find.byKey(const Key('practice-mission-hub')), findsOneWidget);
    expect(find.byKey(const Key('open-situation-missions')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('game search filters the catalog and keeps match discoverable', (
    tester,
  ) async {
    await _pumpPracticeHub(tester);

    expect(find.byKey(const Key('practice-game-search')), findsOneWidget);
    expect(find.byKey(const Key('practice-surprise-game')), findsOneWidget);
    expect(find.byKey(const Key('start-recommended-practice')), findsNothing);
    expect(find.byKey(const Key('practice-activity-매치 스프린트')), findsOneWidget);

    final search = find.byKey(const Key('practice-game-search'));
    await _ensureVisible(tester, search);
    await tester.enterText(search, '매치');
    await tester.pump();

    expect(find.byKey(const Key('practice-activity-매치 스프린트')), findsOneWidget);
    expect(find.byKey(const Key('practice-activity-혼합 퀴즈')), findsNothing);

    await tester.enterText(search, '존재하지 않는 게임');
    await tester.pump();
    expect(find.text('조건에 맞는 게임이 없어요.'), findsOneWidget);

    await tester.tap(find.byTooltip('검색 지우기'));
    await tester.pump();
    expect(find.byKey(const Key('practice-activity-혼합 퀴즈')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sound discrimination stays disabled until three choices exist', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    final controller = harness.container.read(appControllerProvider.notifier);
    const subjectId = 'general:listening-readiness';
    await controller.upsertStudySubject(
      const StudySubject(
        id: subjectId,
        kind: StudySubjectKind.general,
        name: '듣기 준비도',
        description: '후보 수 검증',
        symbol: '🎧',
        contentLanguage: LanguageTag.english,
      ),
    );
    for (final item in const [
      LearningItem(
        id: 'sound-ship',
        subjectId: subjectId,
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'ship',
        translations: ['배'],
        acceptedAnswers: ['배'],
        capabilities: {ExerciseCapability.listening},
      ),
      LearningItem(
        id: 'sound-sheep',
        subjectId: subjectId,
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'sheep',
        translations: ['양'],
        acceptedAnswers: ['양'],
        capabilities: {ExerciseCapability.listening},
      ),
    ]) {
      await controller.upsertCustomItem(item);
    }
    controller.selectSubject(subjectId);
    await tester.pumpAndSettle();
    if (find.byKey(const Key('practice-game-search')).evaluate().isEmpty) {
      await tester.tap(find.text('전체 게임'));
      await tester.pumpAndSettle();
    }

    final card = find.byKey(const Key('practice-activity-소리 구별'));
    expect(card, findsOneWidget);
    expect(find.text('듣기 가능한 표현과 서로 구별되는 후보가 최소 3개 필요해요.'), findsOneWidget);
    final material = tester.widget<Material>(card);
    expect(material.child, isA<InkWell>());
    final inkWell = material.child! as InkWell;
    expect(inkWell.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite hide and restore update and persist the catalog', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    const activityId = 'meaning-choice';
    const activityTitle = '뜻 고르기';

    await _openActivityMenu(tester, activityId, activityTitle);
    await tester.tap(find.text('즐겨찾기에 고정').last);
    await tester.pumpAndSettle();

    var catalog = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog;
    expect(catalog.favoriteActivityIds, contains(activityId));
    expect(find.text('즐겨찾는 게임'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('즐겨찾는 게임')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('practice-category-암기'))).dy,
      ),
    );

    await _openActivityMenu(tester, activityId, activityTitle);
    await tester.tap(find.text('이 게임 숨기기').last);
    await tester.pumpAndSettle();

    catalog = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog;
    expect(catalog.favoriteActivityIds, isNot(contains(activityId)));
    expect(catalog.hiddenActivityIds, contains(activityId));
    expect(find.byKey(const Key('hidden-practice-games')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('hidden-practice-games')));
    await _tapVisible(tester, find.text('$activityTitle 복원'));

    catalog = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog;
    expect(catalog.hiddenActivityIds, isNot(contains(activityId)));
    expect(
      find.byKey(const Key('practice-activity-$activityTitle')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      harness
          .store
          .savedPreferences
          .interaction
          .practiceCatalog
          .hiddenActivityIds,
      isNot(contains(activityId)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendation starts directly while settings stays available', (
    tester,
  ) async {
    await _pumpPracticeHub(
      tester,
      now: () => DateTime.fromMicrosecondsSinceEpoch(0),
      openGames: false,
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('start-recommended-practice')),
    );
    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.byKey(const Key('start-practice-session')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('configure-recommended-practice')),
    );
    expect(find.byKey(const Key('start-practice-session')), findsOneWidget);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('practice-surprise-game')));
    expect(find.byKey(const Key('start-practice-session')), findsOneWidget);
    expect(find.byKey(const Key('practice-advanced-settings')), findsOneWidget);
    expect(find.byKey(const Key('practice-record-progress')), findsNothing);
    expect(find.byKey(const Key('practice-history-all')), findsNothing);
    expect(find.byKey(const Key('practice-priority-dueFirst')), findsNothing);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'practice hub explains recommendation inputs and daily challenge',
    (tester) async {
      final harness = await _pumpPracticeHub(tester, openGames: false);

      expect(find.byKey(const Key('practice-daily-challenge')), findsOneWidget);
      expect(find.byKey(const Key('practice-daily-quest-0')), findsOneWidget);
      expect(find.byKey(const Key('practice-daily-quest-1')), findsOneWidget);
      expect(find.byKey(const Key('practice-daily-quest-2')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('practice-daily-quest-progress')),
            )
            .data,
        '0/3 완료',
      );
      expect(find.text('오늘의 3가지 도전'), findsOneWidget);
      final challengeTitle = tester
          .widget<Text>(find.textContaining('오늘의 도전 ·').first)
          .data!;
      final basis = find.byKey(const Key('practice-recommendation-basis'));
      expect(basis, findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('personalized-practice-hub')))
            .height,
        100,
      );
      expect(
        find.descendant(of: basis, matching: find.text('복습 0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: basis, matching: find.text('오답 0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: basis, matching: find.text('최근 정확도 -')),
        findsOneWidget,
      );
      harness.container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      harness.container.read(appRouterProvider).go('/learn');
      await tester.pumpAndSettle();
      expect(find.text(challengeTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows practice recommendations expose controls and keyboard scrolling',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await _pumpPracticeHub(
          tester,
          openGames: false,
          size: const Size(320, 720),
        );

        final listFinder = find.byKey(const Key('personalized-practice-hub'));
        final previousFinder = find.byKey(
          const Key('practice-hub-scroll-previous'),
        );
        final nextFinder = find.byKey(const Key('practice-hub-scroll-next'));
        final controller = tester.widget<ListView>(listFinder).controller!;

        expect(find.byKey(const Key('practice-hub-scrollbar')), findsOneWidget);
        expect(previousFinder, findsOneWidget);
        expect(nextFinder, findsOneWidget);
        expect(tester.widget<IconButton>(previousFinder).onPressed, isNull);
        expect(tester.widget<IconButton>(nextFinder).onPressed, isNotNull);
        expect(controller.offset, 0);

        await tester.tap(nextFinder);
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expect(tester.widget<IconButton>(previousFinder).onPressed, isNotNull);

        final scrollFocus = tester.widget<Focus>(
          find.byKey(const Key('practice-hub-scroll-focus')),
        );
        scrollFocus.focusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.maxScrollExtent);
        expect(tester.widget<IconButton>(nextFinder).onPressed, isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        await tester.drag(
          listFinder,
          const Offset(-120, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(listFinder),
            scrollDelta: const Offset(0, 90),
            kind: PointerDeviceKind.mouse,
          ),
        );
        await tester.pump();
        expect(controller.offset, greaterThan(0));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('15 minute preset shows its estimated item count and launches', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    await _openPracticeActivity(tester, '혼합 퀴즈');

    final preset = find.byKey(const Key('practice-time-fifteenMinutes'));
    expect(preset, findsOneWidget);
    await _tapVisible(tester, preset);

    expect(tester.widget<ChoiceChip>(preset).selected, isTrue);
    final inlineEstimate = find.byKey(
      const Key('practice-time-selected-estimate'),
    );
    expect(inlineEstimate, findsOneWidget);
    expect(
      find.descendant(
        of: inlineEstimate,
        matching: find.text('선택 · 15분 · 예상 36문제'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(inlineEstimate).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('practice-time-options'))).dy,
      ),
    );
    final estimate = find.byKey(const Key('practice-session-estimate'));
    expect(estimate, findsOneWidget);
    expect(
      find.descendant(
        of: estimate,
        matching: find.textContaining('15분 · 약 36문제'),
      ),
      findsOneWidget,
    );

    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));
    final plan = harness.container
        .read(appControllerProvider.notifier)
        .activeSessionPlan;
    expect(plan.lengthMode, StudySessionLengthMode.timeBudget);
    expect(plan.timeBudgetMinutes, 15);
    expect(plan.itemLimit, 36);
    expect(tester.takeException(), isNull);
  });

  testWidgets('started games are recorded and exposed from the recent row', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);

    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    var catalog = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog;
    expect(catalog.recentActivityIds.first, 'mixed-quiz');

    harness.container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recent-practice-games')), findsOneWidget);
    expect(find.byKey(const Key('recent-practice-mixed-quiz')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('recent-practice-games'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('practice-category-암기'))).dy,
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    catalog = harness.store.savedPreferences.interaction.practiceCatalog;
    expect(catalog.recentActivityIds.first, 'mixed-quiz');
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendation-only games remain reachable from recent games', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester, openGames: false);

    await _tapVisible(
      tester,
      find.byKey(const Key('start-recommended-practice')),
    );
    final recentId = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog
        .recentActivityIds
        .first;
    expect(recentId, 'words-review');

    harness.container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('recent-practice-$recentId')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick launch skips setup while its menu keeps setup reachable', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    const activityId = 'mixed-quiz';

    await _openActivityMenu(tester, activityId, '혼합 퀴즈');
    await tester.tap(find.text('저장 설정으로 바로 시작').last);
    await tester.pumpAndSettle();
    expect(
      harness.container
          .read(appControllerProvider)
          .preferences
          .interaction
          .practiceCatalog
          .quickLaunchActivityIds,
      contains(activityId),
    );

    await _tapVisible(
      tester,
      find.byKey(const Key('practice-activity-혼합 퀴즈')).first,
    );
    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.byKey(const Key('start-practice-session')), findsNothing);

    harness.container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await _openActivityMenu(tester, activityId, '혼합 퀴즈');
    await tester.tap(find.text('저장 설정 변경').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-practice-session')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites can be moved forward with a persisted stable order', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);

    await _openActivityMenu(tester, 'meaning-choice', '뜻 고르기');
    await tester.tap(find.text('즐겨찾기에 고정').last);
    await tester.pumpAndSettle();
    await _openActivityMenu(tester, 'production-writing', '직접 쓰기');
    await tester.tap(find.text('즐겨찾기에 고정').last);
    await tester.pumpAndSettle();

    await _openActivityMenu(tester, 'production-writing', '직접 쓰기');
    await tester.tap(find.text('즐겨찾기에서 앞으로').last);
    await tester.pumpAndSettle();

    final catalog = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog;
    expect(catalog.favoriteActivityOrder, const [
      'production-writing',
      'meaning-choice',
    ]);
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      harness
          .store
          .savedPreferences
          .interaction
          .practiceCatalog
          .favoriteActivityOrder,
      const ['production-writing', 'meaning-choice'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch presets reach the session plan and persist per game', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    const activityId = '/study?mode=mixed';

    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-time-fiveMinutes')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-difficulty-challenge')),
    );
    expect(
      find.byKey(const Key('practice-history-excludeCorrect')),
      findsNothing,
    );
    expect(find.byKey(const Key('practice-priority-newFirst')), findsNothing);
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-advanced-settings')),
    );
    expect(
      find.byKey(const Key('practice-advanced-history-and-order')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-history-excludeCorrect')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-priority-newFirst')),
    );
    expect(find.byKey(const Key('practice-quick-rules')), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-record-progress')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-direction-meaningToLearning')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-grading-lenient')),
    );
    await _tapVisible(tester, find.byKey(const Key('practice-choice-count-2')));
    await _tapVisible(tester, _switchTile('힌트 허용'));
    await _tapVisible(tester, _switchTile('정답 뒤 자동 진행'));
    await _tapVisible(tester, _switchTile('게임 효과음'));
    await _tapVisible(tester, _switchTile('큰 조작 버튼'));
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    final controller = harness.container.read(appControllerProvider.notifier);
    final plan = controller.activeSessionPlan;
    expect(plan.lengthMode, StudySessionLengthMode.timeBudget);
    expect(plan.timeBudgetMinutes, 5);
    expect(plan.queuePriority, StudyQueuePriority.newFirst);
    expect(plan.historyFilter, StudyHistoryFilter.excludeCorrect);
    expect(plan.recordProgress, isFalse);
    expect(
      plan.answerDirectionOverride,
      StudyAnswerDirection.meaningToLearning,
    );
    expect(plan.gradingStrictness, StudyGradingStrictness.lenient);
    expect(plan.choiceCount, 2);
    expect(plan.hintsEnabled, isTrue);
    expect(plan.autoAdvanceOverride, isFalse);
    expect(plan.soundEffectsOverride, isTrue);
    expect(plan.largeControls, isTrue);

    final study = tester.widget<StudyScreen>(find.byType(StudyScreen));
    expect(study.customPlan, isTrue);
    expect(study.queuePriority, StudyQueuePriority.newFirst);
    expect(study.historyFilter, StudyHistoryFilter.excludeCorrect);

    var launch = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog
        .launchFor(activityId);
    _expectCustomizedLaunch(launch);
    await tester.pump(const Duration(milliseconds: 30));
    launch = harness.store.savedPreferences.interaction.practiceCatalog
        .launchFor(activityId);
    _expectCustomizedLaunch(launch);

    harness.container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-advanced-settings')),
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('practice-time-fiveMinutes')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('practice-difficulty-challenge')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('practice-record-progress')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('practice-direction-meaningToLearning')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('practice-grading-lenient')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('practice-choice-count-2')))
          .selected,
      isTrue,
    );
    expect(tester.widget<SwitchListTile>(_switchTile('힌트 허용')).value, isTrue);
    expect(
      tester.widget<SwitchListTile>(_switchTile('정답 뒤 자동 진행')).value,
      isFalse,
    );
    expect(tester.widget<SwitchListTile>(_switchTile('게임 효과음')).value, isTrue);
    expect(tester.widget<SwitchListTile>(_switchTile('큰 조작 버튼')).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick rules time budget toggle turns on and back off', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _tapVisible(
      tester,
      find.byKey(const Key('practice-advanced-settings')),
    );

    final toggle = find.byKey(const Key('practice-time-budget-toggle'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await _tapVisible(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('practice-time-fiveMinutes')),
          )
          .selected,
      isTrue,
    );

    await _tapVisible(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));
    expect(
      harness.container
          .read(appControllerProvider.notifier)
          .activeSessionPlan
          .lengthMode,
      StudySessionLengthMode.itemCount,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog launch clears a stale one-item selected plan', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    final controller = harness.container.read(appControllerProvider.notifier);
    final availableItems = controller.selectedItems;
    expect(availableItems.length, greaterThan(1));
    final expectedIntrinsicIds = controller
        .queue(
          _fixedNow(),
          mode: StudyMode.mixed,
          itemLimit: StudyLimits.maxSessionItems,
          historyFilter: StudyHistoryFilter.all,
        )
        .map((item) => item.id)
        .toSet();
    final targetCount = availableItems.length.clamp(2, 5);
    controller.updateSessionPlan(
      controller.activeSessionPlan.copyWith(
        deck: StudyDeckScope.selected,
        selectedItemIds: {availableItems.first.id},
        groupIds: {},
        tags: {},
        levels: {},
        includeWords: true,
        includeSentences: true,
        itemLimit: 1,
      ),
    );
    await tester.pumpAndSettle();

    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _tapVisible(tester, find.byKey(Key('practice-count-$targetCount')));
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    final plan = controller.activeSessionPlan;
    expect(plan.deck, StudyDeckScope.selected);
    expect(plan.selectedItemIds, expectedIntrinsicIds);
    expect(plan.selectedItemIds, hasLength(expectedIntrinsicIds.length));
    expect(plan.groupIds, isEmpty);
    expect(plan.tags, isEmpty);
    expect(plan.itemLimit, targetCount);
    expect(
      harness.container.read(appControllerProvider).activeStudySession?.itemIds,
      hasLength(targetCount),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recent wrong practice keeps the queue scoped to wrong items', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester, openGames: false);
    final controller = harness.container.read(appControllerProvider.notifier);
    final items = controller.selectedItems;
    expect(items.length, greaterThan(1));

    controller.recordAnswer(
      item: items.first,
      correct: false,
      studiedAt: _fixedNow().subtract(const Duration(minutes: 2)),
      exerciseType: 'recognition',
    );
    controller.recordAnswer(
      item: items[1],
      correct: true,
      studiedAt: _fixedNow().subtract(const Duration(minutes: 1)),
      exerciseType: 'recognition',
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const Key('practice-recommendation-recent-wrong')),
    );

    final plan = controller.activeSessionPlan;
    expect(plan.deck, StudyDeckScope.selected);
    expect(plan.mode, StudyMode.weak);
    expect(plan.historyFilter, StudyHistoryFilter.wrongOnly);
    expect(plan.selectedItemIds, {items.first.id});
    expect(
      harness.container.read(appControllerProvider).activeStudySession?.itemIds,
      [items.first.id],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom seven-item count persists when reopening the same game', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    const activityId = '/study?mode=mixed';
    final countInput = find.byKey(const Key('practice-count-input'));

    await _openPracticeActivity(tester, '혼합 퀴즈');
    await _ensureVisible(tester, countInput);
    await tester.enterText(countInput, '7');
    await tester.pump();
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    var launch = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog
        .launchFor(activityId);
    expect(
      harness.container
          .read(appControllerProvider.notifier)
          .activeSessionPlan
          .itemLimit,
      7,
    );
    expect(launch.itemCount, 7);
    expect(launch.length, PracticeSessionLength.tenItems);

    harness.container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await _openPracticeActivity(tester, '혼합 퀴즈');
    final reopenedInput = tester.widget<TextField>(countInput);
    expect(reopenedInput.controller?.text, '7');
    expect(find.text('7문제 시작'), findsOneWidget);
    launch = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog
        .launchFor(activityId);
    expect(launch.itemCount, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed count is clamped to the available practice queue', (
    tester,
  ) async {
    final harness = await _pumpPracticeHub(tester);
    final controller = harness.container.read(appControllerProvider.notifier);
    final availableCount = controller
        .queue(_fixedNow(), mode: StudyMode.sentenceOrder, itemLimit: 100)
        .length;
    expect(availableCount, greaterThan(0));
    expect(availableCount, lessThan(100));

    await _openPracticeActivity(tester, '문장 배열');
    final countInput = find.byKey(const Key('practice-count-input'));
    await _ensureVisible(tester, countInput);
    await tester.enterText(countInput, '100');
    await tester.pump();
    expect(find.text('$availableCount문제 시작'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    final plan = controller.activeSessionPlan;
    final launch = harness.container
        .read(appControllerProvider)
        .preferences
        .interaction
        .practiceCatalog
        .launchFor('/study?mode=sentenceOrder');
    expect(plan.itemLimit, availableCount);
    expect(launch.itemCount, availableCount);
    expect(
      harness.container.read(appControllerProvider).activeStudySession?.itemIds,
      hasLength(availableCount),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('match activity launches directly into the match setup', (
    tester,
  ) async {
    await _pumpPracticeHub(tester);

    expect(find.byKey(const Key('practice-activity-매치 스프린트')), findsOneWidget);
    await _openPracticeActivity(tester, '매치 스프린트');
    await _tapVisible(tester, find.byKey(const Key('start-practice-session')));

    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.byKey(const Key('begin-match-sprint')), findsOneWidget);
    final study = tester.widget<StudyScreen>(find.byType(StudyScreen));
    expect(study.startMatchSprint, isTrue);
    expect(study.customPlan, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _PracticeHarness {
  const _PracticeHarness(this.container, this.store);

  final ProviderContainer container;
  final MemoryStudyStore store;
}

DateTime _fixedNow() => DateTime(2026, 8, 2, 12);

Future<_PracticeHarness> _pumpPracticeHub(
  WidgetTester tester, {
  DateTime Function()? now,
  bool openGames = true,
  Size size = const Size(412, 915),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final store = MemoryStudyStore(
    preferences: const StudyPreferences(onboardingCompleted: true),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appClockProvider.overrideWithValue(now ?? _fixedNow),
      ],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav-learn')));
  await tester.pumpAndSettle();
  if (openGames) {
    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SpracheApp)),
  );
  return _PracticeHarness(container, store);
}

Future<void> _openPracticeActivity(WidgetTester tester, String title) async {
  final card = find.byKey(Key('practice-activity-$title')).first;
  await _tapVisible(tester, card);
  expect(find.byKey(const Key('start-practice-session')), findsOneWidget);
}

Future<void> _openActivityMenu(
  WidgetTester tester,
  String activityId,
  String title,
) async {
  await _ensureVisible(
    tester,
    find.byKey(Key('practice-activity-$title')).first,
  );
  await tester.tap(find.byKey(Key('practice-menu-$activityId')).first);
  await tester.pumpAndSettle();
}

Finder _switchTile(String title) => find
    .ancestor(of: find.text(title), matching: find.byType(SwitchListTile))
    .first;

Future<void> _ensureVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _ensureVisible(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void _expectCustomizedLaunch(PracticeLaunchPreferences launch) {
  expect(launch.length, PracticeSessionLength.fiveMinutes);
  expect(launch.itemCount, 12);
  expect(launch.difficulty, PracticeDifficultyPreset.challenge);
  expect(launch.historyScope, PracticeHistoryScope.excludeCorrect);
  expect(launch.queueOrder, PracticeQueueOrder.newFirst);
  expect(launch.answerDirection, StudyAnswerDirection.meaningToLearning);
  expect(launch.gradingStrictness, StudyGradingStrictness.lenient);
  expect(launch.choiceCount, 2);
  expect(launch.recordProgress, isFalse);
  expect(launch.hintsEnabled, isTrue);
  expect(launch.autoAdvance, isFalse);
  expect(launch.soundEnabled, isTrue);
  expect(launch.largeControls, isTrue);
}
