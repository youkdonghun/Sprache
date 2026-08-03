import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/services/window_workspace_service.dart';
import 'package:sprache/src/state/app_state.dart';

DateTime _goldenNow() => DateTime(2026, 7, 27, 10);

void main() {
  testWidgets('mobile core screens stay visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-home.png'),
      );

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-settings.png'),
      );

      await tester.tap(find.text('자료실').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-library.png'),
      );

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-learning-hub.png'),
      );

      final quickPractice = find.byKey(const Key('quick-practice-quiz'));
      await tester.ensureVisible(quickPractice);
      await tester.pumpAndSettle();
      await tester.tap(quickPractice);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-practice-launch.png'),
      );
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study.png'),
      );
      await tester.tap(find.byKey(const Key('study-choice-0')));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study-feedback.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final dark in [false, true]) {
    testWidgets(
      'mobile long reading details ${dark ? 'dark' : 'light'} stay stable',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
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
              overrides: [
                studyStoreProvider.overrideWithValue(store),
                appClockProvider.overrideWithValue(_goldenNow),
              ],
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

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              dark
                  ? 'goldens/mobile-reading-details-dark.png'
                  : 'goldens/mobile-reading-details.png',
            ),
          );
        } finally {
          if (dark) {
            tester.binding.platformDispatcher
                .clearPlatformBrightnessTestValue();
          }
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('mobile quick add ${dark ? 'dark' : 'light'} stays stable', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      if (dark) {
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            Brightness.dark;
      }

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              appClockProvider.overrideWithValue(_goldenNow),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav-library')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('library-add-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('add-quick-word')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('quick-content-text')),
          'workaround',
        );
        await tester.enterText(
          find.byKey(const Key('quick-content-meaning')),
          '우회 방법',
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            dark
                ? 'goldens/mobile-quick-add-dark.png'
                : 'goldens/mobile-quick-add.png',
          ),
        );
      } finally {
        if (dark) {
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        }
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }

  testWidgets('compact mobile core screens stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-home.png'),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-settings.png'),
      );

      container.read(appRouterProvider).go('/library');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-library.png'),
      );

      container.read(appRouterProvider).go('/learn');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-learning-hub.png'),
      );

      container.read(appRouterProvider).go('/stats');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-stats.png'),
      );

      container.read(appRouterProvider).go('/session-builder');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-compact-session-builder.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop home stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-home.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile session management stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-session-management.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop session management stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-session-management.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop study feedback stays compact and modal', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('study-choice-0')));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();

      final popupSize = tester.getSize(
        find.byKey(const Key('study-feedback-popup')),
      );
      expect(popupSize.width, lessThanOrEqualTo(420));
      expect(popupSize.height, lessThanOrEqualTo(560));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-study-feedback.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile session builder stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-session-builder.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark session builder stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-session-builder-dark-v2.png'),
      );
    } finally {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop session builder stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-session-builder.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Windows focus home and window tools stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 640);
    final driver = _GoldenWindowWorkspaceDriver();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            windowWorkspaceDriverProvider.overrideWithValue(driver),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('window-compact-toggle')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/windows-focus-home.png'),
      );

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('windows-workspace-card')),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/windows-workspace-settings.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark surfaces stay visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-home-dark.png'),
      );

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-settings-dark.png'),
      );

      await tester.tap(find.text('자료실'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-library-dark.png'),
      );

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-learning-hub-dark-v2.png'),
      );

      final quickPractice = find.byKey(const Key('quick-practice-quiz'));
      await tester.ensureVisible(quickPractice);
      await tester.pumpAndSettle();
      await tester.tap(quickPractice);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-practice-launch-dark.png'),
      );
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      container.read(appRouterProvider).go('/study?mode=meaning');
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study-dark.png'),
      );
      await tester.tap(find.byKey(const Key('study-choice-0')));
      await tester.tap(find.text('정답 확인'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study-feedback-dark.png'),
      );
    } finally {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile card and pronunciation screens stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-flashcard-v2.png'),
      );
      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-flashcard-rating-v2.png'),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('발음 따라하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('발음 따라하기'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-pronunciation.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile resume and review forecast stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final startedAt = DateTime(2026, 7, 27, 9);
    final items = sampleContent
        .where((item) => item.learningLanguage.code == 'en')
        .take(10)
        .toList();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appClockProvider.overrideWithValue(_goldenNow),
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                activeStudySession: ActiveStudySession(
                  sessionId: 'golden-resume',
                  courseId: 'ko-en',
                  mode: StudyMode.meaning,
                  itemIds: items.map((item) => item.id).toList(),
                  currentIndex: 3,
                  correctCount: 2,
                  wrongCount: 1,
                  earnedXp: 25,
                  startedAt: startedAt,
                  updatedAt: startedAt.add(const Duration(minutes: 3)),
                  phase: ActiveStudySessionPhase.paused,
                  pauseCount: 1,
                ),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-resume-home.png'),
      );

      await tester.tap(find.text('기록').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-review-report.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('dark resume, card rating, and review forecast stay stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    final startedAt = DateTime(2026, 7, 27, 9);
    final items = sampleContent
        .where((item) => item.learningLanguage.code == 'en')
        .take(10)
        .toList();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appClockProvider.overrideWithValue(_goldenNow),
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                activeStudySession: ActiveStudySession(
                  sessionId: 'golden-resume-dark',
                  courseId: 'ko-en',
                  mode: StudyMode.meaning,
                  itemIds: items.map((item) => item.id).toList(),
                  currentIndex: 3,
                  correctCount: 2,
                  wrongCount: 1,
                  earnedXp: 25,
                  startedAt: startedAt,
                  updatedAt: startedAt.add(const Duration(minutes: 3)),
                  phase: ActiveStudySessionPhase.paused,
                  pauseCount: 1,
                ),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-resume-home-dark-v2.png'),
      );

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-flashcard-rating-dark.png'),
      );

      await tester.tap(find.byKey(const Key('close-flashcards')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기록').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-review-report-dark.png'),
      );
    } finally {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile course path and unit guide stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-course-path')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-course-path.png'),
      );

      await tester.tap(find.text('단원 가이드').first);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-unit-guide.png'),
      );

      await tester.ensureVisible(find.byKey(const Key('open-unit-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-unit-notes')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-unit-notes-v2.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark course surfaces stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-course-path')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-course-path-dark.png'),
      );

      await tester.tap(find.text('단원 가이드').first);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-unit-guide-dark.png'),
      );

      await tester.ensureVisible(find.byKey(const Key('open-unit-notes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-unit-notes')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-unit-notes-dark-v2.png'),
      );
    } finally {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile situation mission stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-missions.png'),
      );

      await tester.tap(find.byKey(const Key('start-recommended-mission')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-mission-practice.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mobile dark mission practice stays visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-recommended-mission')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-mission-practice-dark.png'),
      );
    } finally {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop mission catalog stays visually stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('practice-category-실전')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('실전 상황 미션'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-missions.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('desktop unit expression notes stay visually stable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(_goldenNow),
          ],
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
      await tester.tap(find.byKey(const Key('open-unit-notes')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/desktop-unit-notes.png'),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

class _GoldenWindowWorkspaceDriver implements WindowWorkspaceDriver {
  @override
  Future<void> minimize() async {}

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {}

  @override
  Future<void> setCompact(bool compact) async {}
}
