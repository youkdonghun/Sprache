import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
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

      await tester.tap(find.text('단어장').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-library.png'),
      );

      await tester.tap(find.text('연습').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-learning-hub.png'),
      );

      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study.png'),
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
      await tester.tap(find.text('자유 학습'));
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
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-session-builder-dark.png'),
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
      await tester.tap(find.text('자유 학습'));
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

      await tester.tap(find.text('단어장'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-library-dark.png'),
      );

      await tester.tap(find.text('연습'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-learning-hub-dark.png'),
      );

      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -620),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-study-dark.png'),
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
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-flashcards')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-flashcard.png'),
      );
      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile-flashcard-rating.png'),
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('learning-hub-scroll')),
        const Offset(0, -1400),
      );
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
        matchesGoldenFile('goldens/mobile-resume-home-dark.png'),
      );

      await tester.tap(find.text('연습').last);
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
      await tester.tap(find.text('코스 여정'));
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
        matchesGoldenFile('goldens/mobile-unit-notes.png'),
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
      await tester.tap(find.text('코스 여정'));
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
        matchesGoldenFile('goldens/mobile-unit-notes-dark.png'),
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
      await tester.tap(find.text('연습').last);
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
      await tester.tap(find.text('연습').last);
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
      await tester.tap(find.text('연습').first);
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
      await tester.tap(find.text('코스 여정'));
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
