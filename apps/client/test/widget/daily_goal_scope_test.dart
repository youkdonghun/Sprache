import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'home, settings, and report distinguish course XP from account XP',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      final store = MemoryStudyStore(
        profile: const StoredProfile(
          selectedLanguage: LanguageTag.english,
          totalXp: 400,
          streakDays: 3,
          dailyXp: 25,
          dailyXpByCourse: {'ko-en': 10, 'ko-ja': 15},
          badges: {},
          driveConnected: false,
          progress: {},
        ),
        preferences: const StudyPreferences(
          onboardingCompleted: true,
          activeSubjectId: 'language:en',
          dailyGoal: 100,
          dailyGoalsBySubject: {'language:en': 50, 'language:ja': 200},
          weeklyTargetDays: 3,
          weeklyTargetMinutes: 60,
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

        expect(find.textContaining('오늘 10/50 XP · Lv.1'), findsOneWidget);
        expect(find.textContaining('누적 400'), findsOneWidget);
        await tester.tap(find.byKey(const Key('home-simple-details-toggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('home-weekly-target-summary')),
          findsOneWidget,
        );
        expect(
          find.textContaining('0/3일 · 0/60분', findRichText: true),
          findsOneWidget,
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final controller = container.read(appControllerProvider.notifier);
        controller.selectLanguage(LanguageTag.japanese);
        await tester.pumpAndSettle();
        expect(find.textContaining('오늘 15/200 XP · Lv.1'), findsOneWidget);
        expect(find.textContaining('누적 400'), findsOneWidget);

        await tester.tap(find.byKey(const Key('home-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('settings-overview-learning')));
        await tester.pumpAndSettle();
        expect(find.text('일본어 하루 목표'), findsOneWidget);
        expect(find.text('오늘 15 XP · 전체 누적 400 XP'), findsOneWidget);

        await tester.tap(find.byKey(const Key('nav-home')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav-stats')));
        await tester.pumpAndSettle();
        expect(find.text('ACCOUNT LEVEL 1'), findsOneWidget);
        expect(find.text('계정 전체에서 지금까지 400 XP를 쌓았어요'), findsOneWidget);
        expect(find.text('일본어 오늘 XP'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('weekly-target-5')));
        await tester.tap(find.byKey(const Key('weekly-target-5')));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const Key('weekly-minute-target-90')),
        );
        await tester.tap(find.byKey(const Key('weekly-minute-target-90')));
        await tester.pump(const Duration(milliseconds: 80));
        await controller.flushPendingWrites();
        expect(store.savedPreferences.weeklyTargetDays, 5);
        expect(store.savedPreferences.weeklyTargetMinutes, 90);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('home hides yesterday XP before the first answer of a new day', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    final store = MemoryStudyStore(
      profile: StoredProfile(
        selectedLanguage: LanguageTag.english,
        totalXp: 40,
        streakDays: 2,
        dailyXp: 20,
        dailyXpByCourse: const {'ko-en': 20},
        badges: const {},
        driveConnected: false,
        progress: const {},
        lastStudyDate: DateTime(2026, 7, 30, 23, 55),
      ),
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:en',
        dailyGoal: 20,
      ),
    );
    var now = DateTime(2026, 7, 30, 23, 59);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            appClockProvider.overrideWithValue(() => now),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('오늘 20/20 XP'), findsOneWidget);
      now = DateTime(2026, 7, 31, 0, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.textContaining('오늘 0/20 XP'), findsOneWidget);
      expect(find.textContaining('누적 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
