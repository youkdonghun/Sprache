import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/home_screen.dart';
import 'package:sprache/src/screens/learning_hub_screen.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/services/window_workspace_service.dart';
import 'package:sprache/src/state/app_state.dart';

Future<void> _selectAllGames(WidgetTester tester) async {
  final advancedToggle = find.byKey(const Key('toggle-advanced-practice'));
  if (advancedToggle.evaluate().isNotEmpty) {
    await tester.ensureVisible(advancedToggle);
    await tester.tap(advancedToggle);
    await tester.pumpAndSettle();
  }
  final gamesTab = find.text('전체 게임');
  expect(gamesTab, findsOneWidget);
  await tester.ensureVisible(gamesTab);
  await tester.pumpAndSettle();
  await tester.tap(gamesTab);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(375, 812),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ]) {
    testWidgets(
      'mobile workspace fits ${size.width.toInt()}px without overflow',
      (tester) async {
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

          expect(find.text('바로 학습'), findsOneWidget);
          await tester.tap(find.byKey(const Key('nav-learn')));
          await tester.pumpAndSettle();
          await _selectAllGames(tester);
          expect(find.text('추가 학습'), findsOneWidget);
          await tester.drag(
            find.byKey(const Key('learning-hub-scroll')),
            const Offset(0, -1500),
          );
          await tester.pumpAndSettle();

          final container = ProviderScope.containerOf(
            tester.element(find.byType(SpracheApp)),
          );
          for (final route in const [
            '/path',
            '/library',
            '/stats',
            '/settings',
            '/session-builder',
          ]) {
            container.read(appRouterProvider).go(route);
            await tester.pumpAndSettle();
            if (route == '/settings') {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -2400),
              );
              await tester.pumpAndSettle();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$route overflowed at ${size.width.toInt()}px',
            );
          }
          if (size.width <= 360) {
            for (final route in const [
              '/cards?kind=words',
              '/study?mode=meaning',
              '/pronunciation',
              '/missions',
              '/mission/0',
              '/unit/0',
              '/notes/0',
              '/import',
              '/library/new',
            ]) {
              container.read(appRouterProvider).go(route);
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '$route overflowed at ${size.width.toInt()}px compact width',
              );
            }
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      },
    );
  }

  testWidgets('primary tabs switch without a page transition', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                preferences: const StudyPreferences(onboardingCompleted: true),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LearningHubScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-library')));
      await tester.pumpAndSettle();
      expect(find.byType(LearningHubScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('library-search-field')),
        'remember-me',
      );
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-library')));
      await tester.pumpAndSettle();
      final searchField = tester.widget<TextField>(
        find.byKey(const Key('library-search-field'), skipOffstage: false),
      );
      expect(searchField.controller?.text, 'remember-me');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

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

      expect(find.text('바로 학습'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      expect(find.text('추가 학습'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('설정'), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('compact mobile workspace supports 1.3x accessibility text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('바로 학습'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      for (final route in const [
        '/learn',
        '/library',
        '/stats',
        '/settings',
        '/session-builder',
      ]) {
        container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflowed at 320px with 1.3x text',
        );
      }
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('learning hub and quiz controls support 2.0x text', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      expect(find.text('추가 학습'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning&limit=5');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('submit-study-answer')), findsOneWidget);
      expect(find.byKey(const Key('give-up-study-question')), findsOneWidget);
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

    expect(find.text('바로 학습'), findsOneWidget);
    expect(find.textContaining('영어'), findsWidgets);
  });

  testWidgets('home primary action honors the preferred study mode', (
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      final state = container.read(appControllerProvider);
      container
          .read(appControllerProvider.notifier)
          .updatePreferences(
            state.preferences.copyWith(preferredMode: StudyMode.listening),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-primary-study-button')));
      await tester.pumpAndSettle();

      expect(find.text('소리를 듣고 받아쓰세요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
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

      expect(find.text('오늘 학습'), findsOneWidget);
      expect(find.text('바로 학습'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Windows home keeps window controls in shortcuts, not header', (
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

      expect(find.byKey(const Key('window-compact-toggle')), findsNothing);
      expect(find.byKey(const Key('window-quick-minimize')), findsNothing);
      expect(find.byKey(const Key('home-settings')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(driver.compact, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(driver.minimizeCount, 1);
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
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                profile: const StoredProfile(
                  selectedLanguage: LanguageTag.japanese,
                  totalXp: 0,
                  streakDays: 0,
                  dailyXp: 0,
                  badges: {},
                  driveConnected: false,
                  progress: {},
                ),
                preferences: const StudyPreferences(
                  onboardingCompleted: true,
                  activeSubjectId: 'language:ja',
                ),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('바로 학습'), findsOneWidget);
      expect(find.text('일본어'), findsOneWidget);
      expect(find.text('자료실'), findsWidgets);
      expect(find.text('학습'), findsOneWidget);
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
      expect(find.byKey(const Key('home-simple-details')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-simple-details-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('home-today-plan-summary-row')),
        findsOneWidget,
      );
      expect(find.text('복습 예정'), findsOneWidget);
      expect(find.text('새 표현'), findsOneWidget);
      expect(find.text('학습 범위'), findsNothing);
      expect(find.text('바로 학습'), findsOneWidget);
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

      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();
      expect(find.text('영어 자료실'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('library-search-field')),
        '검색될 수 없는 표현 12345',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

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
      await tester.tap(find.byKey(const Key('settings-overview-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('데이터와 개인정보'), findsOneWidget);
      expect(find.text('Drive에서 보는 범위'), findsOneWidget);
      expect(find.textContaining('운영자'), findsNothing);
      expect(find.text('테스트 모드'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('practice-activity-뜻 고르기')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start-practice-session')), findsOneWidget);
      final inventory = find.byKey(
        const Key('practice-launch-inventory-strip'),
      );
      expect(inventory, findsOneWidget);
      expect(
        find.descendant(of: inventory, matching: find.textContaining('전체 ')),
        findsOneWidget,
      );
      final startSession = find.byKey(const Key('start-practice-session'));
      await tester.ensureVisible(startSession);
      await tester.pumpAndSettle();
      await tester.tap(startSession);
      await tester.pumpAndSettle();
      expect(find.text('알맞은 뜻을 고르세요'), findsOneWidget);
      final compactHud = find.byKey(const Key('compact-study-hud'));
      expect(compactHud, findsOneWidget);
      expect(
        tester.widget<Semantics>(compactHud).properties.label,
        contains('연속 목표 3개'),
      );
      final visibleTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toSet();
      final currentItem = sampleContent.firstWhere(
        (item) =>
            item.learningLanguage == LanguageTag.english &&
            visibleTexts.contains(item.text),
      );

      await tester.tap(find.text(currentItem.translations.first));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();

      expect(find.text('다음 문제'), findsOneWidget);
      expect(find.byKey(const Key('study-feedback-popup')), findsOneWidget);
      final popupSize = tester.getSize(
        find.byKey(const Key('study-feedback-popup')),
      );
      expect(popupSize.width, lessThanOrEqualTo(420));
      expect(popupSize.height, lessThanOrEqualTo(560));
      expect(find.text('정답'), findsOneWidget);
      expect(find.byKey(const Key('feedback-listen-again')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        tester.widget<Semantics>(compactHud).properties.label,
        contains('현재 1콤보'),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('study-feedback-popup')),
          matching: find.text('+10 XP'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('study offers progressive hints and an honest give-up action', (
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=production&limit=5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('show-study-hint')));
      await tester.pump();
      expect(find.byKey(const Key('study-hint-card')), findsOneWidget);
      expect(find.text('힌트 1/2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('give-up-study-question')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study-feedback-popup')), findsOneWidget);
      expect(find.text('모르겠어요'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('study-feedback-popup')),
          matching: find.text('+5 XP'),
        ),
        findsOneWidget,
      );
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
    tester.view.physicalSize = const Size(320, 640);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);

      expect(find.byKey(const Key('quick-practice-quiz')), findsOneWidget);
      expect(find.byKey(const Key('quick-practice-cards')), findsOneWidget);
      expect(
        find.byKey(const Key('quick-practice-pronunciation')),
        findsOneWidget,
      );
      expect(find.text('추가 학습'), findsOneWidget);
      expect(find.text('혼합 퀴즈'), findsWidgets);
      expect(find.text('문장 빈칸'), findsWidgets);
      expect(
        tester.getSize(find.byKey(const Key('practice-activity-혼합 퀴즈'))).width,
        greaterThan(250),
      );
      expect(find.text('단어 카드'), findsOneWidget);
      expect(find.text('문장 카드'), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      await tester.ensureVisible(find.byKey(const Key('start-flashcards')));
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
    tester.view.physicalSize = const Size(320, 640);
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
      expect(find.text('학습 이어하기'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('resume-active-session')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resume-active-session')));
      await tester.pumpAndSettle();

      expect(find.text('2/5'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pause-study-session')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-study-card')), findsOneWidget);
      expect(find.text('중단한 학습 이어하기'), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('practice-activity-문장 빈칸')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice-activity-문장 빈칸')));
      await tester.pumpAndSettle();
      final startSession = find.byKey(const Key('start-practice-session'));
      await tester.ensureVisible(startSession);
      await tester.pumpAndSettle();
      await tester.tap(startSession);
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

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('발음 따라하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('발음 따라하기'));
      await tester.pumpAndSettle();

      expect(find.text('듣고 따라 말하기'), findsOneWidget);
      expect(find.text('발음 듣기'), findsOneWidget);
      expect(find.byKey(const Key('pronunciation-mic')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pronunciation-score-disclosure')));
      await tester.pumpAndSettle();
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

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
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

      for (var index = 0; index < 8; index++) {
        final next = find.byKey(const Key('mission-next-phrase'));
        if (next.evaluate().isEmpty) break;
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        if (find.text('실전 미션 완료').evaluate().isNotEmpty) break;
        final coach = find.byKey(const Key('mission-reveal'));
        if (coach.evaluate().isNotEmpty) {
          await tester.ensureVisible(coach);
          await tester.tap(coach);
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('실전 미션 완료'), findsOneWidget);
      expect(find.text('발음 연습'), findsOneWidget);
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
        await tester.tap(find.byKey(const Key('nav-learn')));
        await tester.pumpAndSettle();
        await _selectAllGames(tester);
        await tester.ensureVisible(
          find.byKey(const Key('practice-category-실전')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('실전 상황 미션'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('start-recommended-mission')));
        await tester.pumpAndSettle();

        expect(find.text('이 미션에 쓸 표현이 없어요'), findsOneWidget);
        expect(find.text('자료실로 이동'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
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
        await tester.tap(find.byKey(const Key('nav-learn')));
        await tester.pumpAndSettle();
        await _selectAllGames(tester);
        await tester.ensureVisible(
          find.byKey(const Key('practice-category-실전')),
        );
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
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await _selectAllGames(tester);

      expect(find.byKey(const Key('compact-learning-header')), findsOneWidget);
      expect(find.text('영어 학습'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
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
    Size(320, 640),
    Size(360, 800),
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
        await tester.tap(find.byKey(const Key('nav-learn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-course-path')));
        await tester.pumpAndSettle();

        expect(find.text('영어 코스 여정'), findsOneWidget);
        expect(find.text('입문 코스 · 6개 단원'), findsOneWidget);
        expect(find.byKey(const Key('course-unit-0')), findsNothing);
        expect(find.byKey(const Key('course-unit-1')), findsOneWidget);
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
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-course-path')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('단원 가이드').first);
      await tester.pumpAndSettle();

      expect(find.text('Unit 1 가이드'), findsOneWidget);
      expect(find.text('이 단원에서 할 수 있는 말'), findsOneWidget);
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
      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();

      const favoriteKey = Key('favorite-en-starter-word-1');
      await tester.enterText(
        find.byKey(const Key('library-search-field')),
        'hello',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(favoriteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(favoriteKey));
      await tester.pumpAndSettle();
      expect(
        store.savedPreferences.favoriteItemIds,
        contains('en-starter-word-1'),
      );

      await tester.drag(
        find.byKey(const Key('mobile-library-scroll')),
        const Offset(0, 1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-mobile-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-sheet-filter-favorites')));
      await tester.tap(find.byKey(const Key('apply-library-advanced-filters')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('mobile-library-scroll')),
        const Offset(0, 1200),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('즐겨찾기 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final dark in [false, true]) {
    for (final size in const [
      Size(375, 812),
      Size(390, 844),
      Size(412, 915),
      Size(430, 932),
    ]) {
      testWidgets('long reading aids use separate lines at '
          '${size.width.toInt()}px ${dark ? 'dark' : 'light'}', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        if (dark) {
          tester.binding.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
        }
        final store = MemoryStudyStore(
          profile: const StoredProfile(
            selectedLanguage: LanguageTag.japanese,
            totalXp: 0,
            streakDays: 0,
            dailyXp: 0,
            badges: {},
            driveConnected: false,
            progress: {},
          ),
          preferences: const StudyPreferences(
            onboardingCompleted: true,
            activeSubjectId: 'language:ja',
          ),
        );
        final item = sampleContent.singleWhere(
          (candidate) => candidate.text == '日本語を勉強しています。',
        );

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [studyStoreProvider.overrideWithValue(store)],
              child: const SpracheApp(),
            ),
          );
          await tester.pumpAndSettle();

          final container = ProviderScope.containerOf(
            tester.element(find.byType(SpracheApp)),
          );
          container.read(appRouterProvider).go('/library');
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('library-search-field')),
            item.text,
          );
          await tester.pumpAndSettle();
          final itemFinder = find.byKey(Key('library-item-${item.id}'));
          await tester.ensureVisible(itemFinder);
          await tester.pumpAndSettle();
          await tester.tap(itemFinder);
          await tester.pumpAndSettle();

          final readingFinder = find.byKey(const Key('item-reading-aids'));
          expect(readingFinder, findsOneWidget);
          final readingText = tester.widget<Text>(readingFinder);
          expect(readingText.data, item.readingAidsLabel);
          expect(readingText.data!.split('\n'), hasLength(3));
          expect(readingText.data, isNot(contains(' · ')));
          expect(tester.takeException(), isNull);
        } finally {
          if (dark) {
            tester.binding.platformDispatcher
                .clearPlatformBrightnessTestValue();
          }
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      });
    }
  }

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
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
        await tester.tap(find.byKey(const Key('nav-learn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-course-path')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('단원 가이드').first);
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
        expect(find.text('이제 직접 써 볼까요?'), findsOneWidget);
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

      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-full-editor')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item-text-field')),
        'accountability',
      );
      await tester.enterText(
        find.byKey(const Key('item-translation-field')),
        '책임감',
      );
      await tester.tap(find.text('표현 저장'));
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
