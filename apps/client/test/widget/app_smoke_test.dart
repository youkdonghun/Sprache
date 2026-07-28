import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/window_workspace_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets('mobile home fits ${size.width.toInt()}px without overflow', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('다음 레슨'), findsOneWidget);
        await tester.tap(find.text('자유 학습'));
        await tester.pumpAndSettle();
        expect(find.text('카드로 먼저 익히기'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('learning-hub-scroll')),
          const Offset(0, -1500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }

  testWidgets('mobile home supports 1.3x accessibility text', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('다음 레슨'), findsOneWidget);
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      expect(find.text('카드로 먼저 익히기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('shows the home learning entry point', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('다음 레슨'), findsOneWidget);
    expect(find.textContaining('영어'), findsWidgets);
  });

  testWidgets('Windows minimum window renders the office-style compact home', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 520);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('오늘 체크리스트'), findsOneWidget);
      expect(find.text('다음 학습'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Windows home controls focus size and quick minimize', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 520);
    final driver = _FakeWindowWorkspaceDriver();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            windowWorkspaceDriverProvider.overrideWithValue(driver),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('window-compact-toggle')), findsOneWidget);
      expect(find.byKey(const Key('window-quick-minimize')), findsOneWidget);
      await tester.tap(find.byKey(const Key('window-compact-toggle')));
      await tester.pumpAndSettle();
      expect(driver.compact, isTrue);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('window-quick-minimize')));
      await tester.pumpAndSettle();
      expect(driver.minimizeCount, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(driver.compact, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(driver.minimizeCount, 2);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Android portrait renders course picker and bottom navigation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('다음 레슨'), findsOneWidget);
      expect(find.text('일본어'), findsOneWidget);
      expect(find.text('단어장'), findsWidgets);
      expect(find.text('코스'), findsOneWidget);
      expect(find.text('연습'), findsOneWidget);
      expect(find.text('기록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('wide Windows layout renders the polished desktop dashboard', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily language desk'), findsOneWidget);
      expect(find.text('오늘의 학습'), findsOneWidget);
      expect(find.text('학습 범위'), findsOneWidget);
      expect(find.text('0%'), findsAtLeastNWidgets(1));
      expect(find.text('다음 레슨'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('library supports search and empty result guidance', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('단어장').last);
      await tester.pumpAndSettle();
      expect(find.text('영어 단어장'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '검색될 수 없는 표현 12345');
      await tester.pump();

      expect(find.text('조건에 맞는 표현이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('settings explains sync scope and local-first privacy', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      expect(find.text('데이터와 개인정보'), findsOneWidget);
      expect(find.textContaining('Railway 데이터베이스'), findsOneWidget);
      expect(find.text('Mock Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('study choice shows graded feedback without mobile overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      expect(find.text('알맞은 뜻을 고르세요'), findsOneWidget);

      final choiceButtons = find.byType(OutlinedButton);
      expect(choiceButtons, findsAtLeastNWidgets(2));
      await tester.tap(choiceButtons.at(1));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();

      expect(find.text('다음 문제'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('learning hub separates study, quiz, sentence, and speaking', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();

      expect(find.text('카드로 먼저 익히기'), findsOneWidget);
      expect(find.text('기억을 꺼내 확인하기'), findsOneWidget);
      expect(find.text('듣고 말하기'), findsOneWidget);
      expect(find.text('단어 카드'), findsOneWidget);
      expect(find.text('문장 카드'), findsOneWidget);
      expect(find.text('문장 빈칸'), findsOneWidget);
      expect(find.text('발음 따라하기'), findsOneWidget);
      expect(find.text('실전 상황 미션'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('flashcards reveal meaning before self rating', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();

      expect(find.text('먼저 소리 내어 읽기'), findsOneWidget);
      expect(find.byKey(const Key('reveal-flashcard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pumpAndSettle();

      expect(find.text('뜻과 읽는 법 확인'), findsOneWidget);
      expect(find.byKey(const Key('flashcard-again')), findsOneWidget);
      expect(find.byKey(const Key('flashcard-hard')), findsOneWidget);
      expect(find.byKey(const Key('flashcard-remembered')), findsOneWidget);
      expect(find.byKey(const Key('flashcard-easy')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('home resumes a locally persisted quiz at the next item', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final startedAt = DateTime.now().subtract(const Duration(minutes: 3));
    final items = sampleContent
        .where((item) => item.learningLanguage.code == 'en')
        .take(5)
        .toList();
    final store = MemoryStudyStore(
      activeStudySession: ActiveStudySession(
        sessionId: 'resume-widget',
        courseId: 'ko-en',
        mode: StudyMode.meaning,
        itemIds: items.map((item) => item.id).toList(),
        currentIndex: 1,
        correctCount: 1,
        wrongCount: 0,
        earnedXp: 10,
        startedAt: startedAt,
        updatedAt: startedAt.add(const Duration(minutes: 1)),
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

      expect(find.byKey(const Key('resume-study-card')), findsOneWidget);
      expect(find.text('1/5문제'), findsOneWidget);
      await tester.tap(find.byKey(const Key('resume-active-session')));
      await tester.pumpAndSettle();

      expect(find.text('2 / 5'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pause-study-session')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-study-card')), findsOneWidget);
      expect(store.savedActiveStudySession?.currentIndex, 1);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('report shows the real review forecast without mobile overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-forecast-card')), findsOneWidget);
      expect(find.text('복습 일정'), findsOneWidget);
      expect(find.text('향후 2~7일'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('sentence cloze is a directly selectable dedicated mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('문장 빈칸'));
      await tester.pumpAndSettle();

      expect(find.text('빈칸에 들어갈 표현을 고르세요'), findsOneWidget);
      expect(find.textContaining('_____'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('pronunciation practice explains scoring before microphone use', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('연습').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('발음 따라하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('발음 따라하기'));
      await tester.pumpAndSettle();

      expect(find.text('듣고 따라 말하기'), findsOneWidget);
      expect(find.text('목표 발음 듣기'), findsOneWidget);
      expect(find.byKey(const Key('pronunciation-mic')), findsOneWidget);
      expect(find.textContaining('글자 일치도'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('situation mission connects listening meaning and speaking', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final store = MemoryStudyStore();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('연습').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();

      expect(find.text('영어 실전 미션'), findsOneWidget);
      expect(find.text('상황별 3분 미션'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start-recommended-mission')));
      await tester.pumpAndSettle();

      expect(find.text('처음 만난 사람과 인사하기'), findsOneWidget);
      expect(find.byKey(const Key('mission-listen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mission-reveal')));
      await tester.pumpAndSettle();
      expect(find.text('어떻게 지내세요?'), findsOneWidget);

      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(const Key('mission-next-phrase')));
        await tester.pumpAndSettle();
      }
      expect(find.text('실전 미션 완료'), findsOneWidget);
      expect(find.text('발음 채점'), findsOneWidget);
      expect(store.savedPreferences.hasCompletedMission('ko-en', 0), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets(
    'mission guides the user when every unit expression is excluded',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final excluded = sampleContent
          .where(
            (item) =>
                item.learningLanguage.code == 'en' &&
                item.tags.contains('unit-0'),
          )
          .map((item) => item.id)
          .toSet();
      final store = MemoryStudyStore(
        preferences: StudyPreferences(excludedItemIds: excluded),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('연습').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-recommended-mission')));
        await tester.pumpAndSettle();

        expect(find.text('미션에 사용할 표현이 없어요'), findsOneWidget);
        expect(find.text('단어장으로 이동'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets('situation mission fits ${size.width.toInt()}px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('연습').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-recommended-mission')));
        await tester.pumpAndSettle();

        expect(find.text('표현 1 / 3'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('mission-practice-scroll')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }

  testWidgets('Windows compact navigation reaches the full practice hub', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 520);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final practiceDestination = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.grid_view_rounded),
      );
      await tester.tap(practiceDestination);
      await tester.pumpAndSettle();

      expect(find.text('영어 학습실'), findsOneWidget);
      await tester.ensureVisible(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      expect(find.text('실전 상황 미션'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets('course path fits ${size.width.toInt()}px without overflow', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('코스 여정'));
        await tester.pumpAndSettle();

        expect(find.text('영어 코스 여정'), findsOneWidget);
        expect(find.text('입문 코스 · 6개 단원'), findsOneWidget);
        expect(find.byKey(const Key('course-unit-0')), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('course-path-scroll')),
          const Offset(0, -1600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }

  testWidgets('unit guide connects vocabulary, sentences, and lesson steps', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('코스 여정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('단원 가이드').first);
      await tester.pumpAndSettle();

      expect(find.text('Unit 1 가이드'), findsOneWidget);
      expect(find.text('이 단원의 의사소통 목표'), findsOneWidget);
      expect(find.text('이 단원의 표현 노트'), findsOneWidget);
      expect(find.text('핵심 단어'), findsOneWidget);
      expect(find.text('핵심 문장'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('unit-guide-scroll')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(find.text('추천 학습 순서'), findsOneWidget);
      expect(find.byKey(const Key('start-unit-next-lesson')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('library saves an expression and filters to saved items', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final store = MemoryStudyStore();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('단어장').last);
      await tester.pumpAndSettle();

      const favoriteKey = Key('favorite-en-starter-word-1');
      await tester.tap(find.byKey(favoriteKey));
      await tester.pumpAndSettle();
      expect(
        store.savedPreferences.favoriteItemIds,
        contains('en-starter-word-1'),
      );

      await tester.tap(find.text('저장됨'));
      await tester.pumpAndSettle();
      expect(find.byKey(favoriteKey), findsOneWidget);
      expect(find.textContaining('저장 1개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets('unit expression notes fit ${size.width.toInt()}px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('코스 여정'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('단원 가이드').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('open-unit-notes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-unit-notes')));
        await tester.pumpAndSettle();

        expect(find.text('핵심 문형'), findsOneWidget);
        expect(find.text('I am … / My name is …'), findsOneWidget);
        await tester.drag(
          find.byKey(const Key('unit-notes-scroll')),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(find.text('이해했으면 바로 써 보기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }

  testWidgets('a user can add a custom word from the library', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    final store = MemoryStudyStore();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('단어장').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 추가'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item-text-field')),
        'accountability',
      );
      await tester.enterText(
        find.byKey(const Key('item-translation-field')),
        '책임감',
      );
      await tester.tap(find.text('추가하기'));
      await tester.pumpAndSettle();

      expect(find.text('accountability'), findsOneWidget);
      expect(store.savedItems.single.text, 'accountability');
      expect(store.savedItems.single.partOfSpeech, PartOfSpeech.noun);
      expect(store.savedItems.single.source.name, '사용자 직접 입력');
      expect(store.savedItems.single.source.license, 'private');
      await tester.tap(find.text('accountability').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-source-metadata')), findsOneWidget);
      expect(find.text('명사'), findsWidgets);
      expect(find.text('사용자 직접 입력'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

class _FakeWindowWorkspaceDriver implements WindowWorkspaceDriver {
  bool compact = false;
  bool alwaysOnTop = false;
  int minimizeCount = 0;

  @override
  Future<void> minimize() async {
    minimizeCount++;
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {
    alwaysOnTop = enabled;
  }

  @override
  Future<void> setCompact(bool compact) async {
    this.compact = compact;
  }
}
