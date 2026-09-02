import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('a user can save and start a filtered learning session', (
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
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();

      expect(find.text('영어 학습 설정'), findsOneWidget);
      expect(find.text('언어키 · en'), findsOneWidget);
      expect(find.byKey(const Key('session-start-bottom')), findsOneWidget);
      expect(find.text('10문제 시작'), findsOneWidget);
      expect(find.byKey(const Key('session-save-menu-bottom')), findsOneWidget);
      expect(
        tester
            .widget<Material>(find.byKey(const Key('session-actions-bottom')))
            .elevation,
        1,
      );
      final actionsDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const Key('session-actions-border')),
                  )
                  .decoration
              as BoxDecoration;
      expect((actionsDecoration.border! as Border).top.width, 1);

      await _chooseOption(
        tester,
        fieldKey: 'session-deck-select',
        optionKey: 'session-deck-unit',
      );

      await _chooseOption(
        tester,
        fieldKey: 'session-content-kind-select',
        optionKey: 'session-include-words',
      );
      await tester.enterText(find.byKey(const Key('session-limit-input')), '5');
      await tester.pumpAndSettle();

      // Leaving the builder no longer discards the most recent choices.
      expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.unit);
      expect(store.savedPreferences.sessionPlan.includeWords, isTrue);
      expect(store.savedPreferences.sessionPlan.includeSentences, isFalse);
      expect(store.savedPreferences.sessionPlan.itemLimit, 5);

      await _chooseOption(
        tester,
        fieldKey: 'session-save-menu-bottom',
        optionKey: 'session-save-bottom',
      );
      await tester.pump(const Duration(milliseconds: 30));

      expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.unit);
      expect(store.savedPreferences.sessionPlan.includeWords, isTrue);
      expect(store.savedPreferences.sessionPlan.includeSentences, isFalse);
      expect(store.savedPreferences.sessionPlan.itemLimit, 5);
      expect(store.savedPreferences.savedSessionPlans, hasLength(1));
      expect(store.savedPreferences.sessionPlan.planId, isNotEmpty);
      expect(find.byKey(const Key('saved-session-plans')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('session-start-bottom')));
      await tester.tap(find.byKey(const Key('session-start-bottom')));
      await tester.pumpAndSettle();

      expect(find.text('1/5'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'1/5 문제, 정답 0개, 오답 0개')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('saved schedules can be loaded again from the builder', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final notifications = _GrantedStudyNotificationService();
    final now = DateTime.now().toUtc();
    final saved = StudySessionPlan(
      planId: 'saved-commute',
      title: '출근길 복습',
      mode: StudyMode.listening,
      itemLimit: 15,
      scheduledAt: now.add(const Duration(hours: 2)),
      updatedAt: now,
    );
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        sessionPlan: const StudySessionPlan(),
        savedSessionPlans: [saved],
      ),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            studyNotificationServiceProvider.overrideWithValue(notifications),
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

      expect(find.text('출근길 복습'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('load-session-plan-tile-saved-commute')),
      );
      await tester.tap(
        find.byKey(const Key('load-session-plan-tile-saved-commute')),
      );
      await tester.pumpAndSettle();

      expect(store.savedPreferences.sessionPlan.planId, 'saved-commute');
      expect(store.savedPreferences.sessionPlan.mode, StudyMode.listening);
      expect(store.savedPreferences.sessionPlan.itemLimit, 15);
      await tester.pump(const Duration(seconds: 5));

      await _chooseOption(
        tester,
        fieldKey: 'session-save-menu-bottom',
        optionKey: 'session-schedule-bottom',
      );

      expect(notifications.permissionRequests, 1);
      expect(find.textContaining('기기 알림을 저장했습니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('timed recovery practice can be configured without recording', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
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
      await tester.ensureVisible(find.byKey(const Key('open-session-builder')));
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();

      await _chooseOption(
        tester,
        fieldKey: 'session-length-select',
        optionKey: 'session-length-time-budget',
      );
      await _chooseOption(
        tester,
        fieldKey: 'session-time-select',
        optionKey: 'session-time-15',
      );

      await tester.ensureVisible(
        find.byKey(const Key('session-advanced-settings')),
      );
      await tester.tap(find.byKey(const Key('session-advanced-settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('session-backlog-recovery')),
      );
      await tester.tap(find.byKey(const Key('session-backlog-recovery')));
      await tester.pumpAndSettle();
      await _chooseOption(
        tester,
        fieldKey: 'session-backlog-limit-select',
        optionKey: 'session-backlog-limit-20',
      );
      await tester.ensureVisible(
        find.byKey(const Key('session-record-progress')),
      );
      await tester.tap(find.byKey(const Key('session-record-progress')));
      await tester.pumpAndSettle();

      await _chooseOption(
        tester,
        fieldKey: 'session-save-menu-bottom',
        optionKey: 'session-save-bottom',
      );
      await tester.pump(const Duration(milliseconds: 30));

      final plan = store.savedPreferences.sessionPlan;
      expect(plan.lengthMode, StudySessionLengthMode.timeBudget);
      expect(plan.timeBudgetMinutes, 15);
      expect(plan.backlogRecovery.enabled, isTrue);
      expect(plan.backlogRecovery.dailyLimit, 20);
      expect(plan.recordProgress, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets(
    'a user can build pronunciation practice from exact expressions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
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
        await tester.ensureVisible(
          find.byKey(const Key('open-session-builder')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-session-builder')));
        await tester.pumpAndSettle();

        await _chooseOption(
          tester,
          fieldKey: 'session-mode-select',
          optionKey: 'session-mode-pronunciation',
        );
        await _chooseOption(
          tester,
          fieldKey: 'session-deck-select',
          optionKey: 'session-deck-selected',
        );
        expect(find.byKey(const Key('session-item-search')), findsOneWidget);

        final firstItem = find.byType(CheckboxListTile).first;
        await tester.ensureVisible(firstItem);
        await tester.tap(firstItem);
        await tester.pumpAndSettle();

        await _chooseOption(
          tester,
          fieldKey: 'session-save-menu-bottom',
          optionKey: 'session-save-bottom',
        );
        await tester.pump(const Duration(milliseconds: 30));

        expect(
          store.savedPreferences.sessionPlan.deck,
          StudyDeckScope.selected,
        );
        expect(
          store.savedPreferences.sessionPlan.mode,
          StudyMode.pronunciation,
        );
        expect(
          store.savedPreferences.sessionPlan.selectedItemIds,
          hasLength(1),
        );

        await tester.ensureVisible(
          find.byKey(const Key('session-start-bottom')),
        );
        await tester.tap(find.byKey(const Key('session-start-bottom')));
        await tester.pumpAndSettle();

        expect(find.text('듣고 따라 말하기'), findsOneWidget);
        expect(find.text('1 / 1'), findsOneWidget);
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
    Size(430, 932),
    Size(1024, 720),
  ]) {
    testWidgets('session builder fits ${size.width.toInt()}px', (tester) async {
      debugDefaultTargetPlatformOverride = size.width >= 900
          ? TargetPlatform.windows
          : TargetPlatform.android;
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
        await tester.ensureVisible(
          find.byKey(const Key('open-session-builder')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-session-builder')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const Key('session-builder-scroll')),
          const Offset(0, -2200),
        );
        await tester.pumpAndSettle();

        if (size.width >= 900) {
          await tester.ensureVisible(
            find.byKey(const Key('desktop-session-advanced-settings')),
          );
          await tester.tap(
            find.byKey(const Key('desktop-session-advanced-settings')),
          );
          await tester.pumpAndSettle();
          expect(find.text('레벨과 태그'), findsOneWidget);
        } else {
          expect(find.text('간단 설정'), findsOneWidget);
          expect(find.text('세부 설정'), findsOneWidget);
          expect(find.byKey(const Key('session-start-bottom')), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}

Future<void> _chooseOption(
  WidgetTester tester, {
  required String fieldKey,
  required String optionKey,
}) async {
  final field = find.byKey(Key(fieldKey));
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  final option = find.byKey(Key(optionKey));
  expect(option, findsWidgets);
  await tester.tap(option.last);
  await tester.pumpAndSettle();
}

class _GrantedStudyNotificationService implements StudyNotificationService {
  var permissionRequests = 0;

  @override
  Future<StudyNotificationPermission> requestPermission() async {
    permissionRequests += 1;
    return StudyNotificationPermission.granted;
  }

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) async {
    return StudyNotificationReconcileResult(
      available: true,
      scheduledCount: buildStudyNotificationSpecs(
        plans,
        now: now ?? DateTime.now(),
      ).length,
    );
  }
}
