import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/adaptive_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'strategy, safe preview, break, reading and TTS are session-only',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1000);
      addTearDown(tester.view.reset);
      const preferences = StudyPreferences(
        ttsRate: 0.45,
        interaction: StudyInteractionPreferences(
          showKoreanReading: true,
          showNativeReading: true,
        ),
      );
      final harness = await _pumpStudy(
        tester,
        preferences: preferences,
        screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 5),
      );
      final prompt = tester
          .widget<Text>(find.byKey(const Key('study-question-prompt')))
          .data!;

      expect(
        find.byKey(const Key('adaptive-recommendation-reason')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('preview-adaptive-study-queue')),
      );
      await tester.tap(find.byKey(const Key('preview-adaptive-study-queue')));
      await tester.pumpAndSettle();

      final preview = find.byKey(const Key('study-queue-preview-sheet'));
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.textContaining('단어')),
        findsWidgets,
      );
      expect(
        find.descendant(of: preview, matching: find.text(prompt)),
        findsNothing,
      );
      Navigator.of(tester.element(preview)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-session-management')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('study-session-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('session-strategy-balanced')));
      await tester.tap(find.byKey(const Key('session-korean-reading')));
      await tester.ensureVisible(find.byKey(const Key('session-break-10')));
      await tester.tap(find.byKey(const Key('session-break-10')));
      await tester.ensureVisible(find.byKey(const Key('session-tts-rate')));
      await tester.drag(
        find.byKey(const Key('session-tts-rate')),
        const Offset(160, 0),
      );
      await tester.ensureVisible(
        find.byKey(const Key('apply-session-quiz-options')),
      );
      await tester.tap(find.byKey(const Key('apply-session-quiz-options')));
      await tester.pumpAndSettle();

      final active = harness.controller.state.activeStudySession!;
      expect(active.runtimeOptions.strategy, StudySessionStrategy.balanced);
      expect(active.runtimeOptions.breakReminderMinutes, 10);
      expect(active.runtimeOptions.showKoreanReading, isFalse);
      expect(active.runtimeOptions.ttsRate, greaterThan(0.45));
      expect(harness.controller.state.preferences.ttsRate, 0.45);
      expect(
        harness.controller.state.preferences.interaction.showKoreanReading,
        isTrue,
      );
      expect(
        _textWithin(
          tester,
          find.byKey(const Key('adaptive-recommendation-reason')),
        ),
        contains('균형'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unfinished typed answer can be restored or discarded on resume',
    (tester) async {
      final harness = await _pumpStudy(
        tester,
        preferences: const StudyPreferences(),
        screen: const StudyScreen(mode: StudyMode.production, itemLimit: 2),
      );

      await tester.enterText(find.byType(TextField), 'unfinished answer');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        harness
            .controller
            .state
            .activeStudySession
            ?.inputCheckpoint
            ?.answerText,
        'unfinished answer',
      );

      await _repumpResume(tester, harness);
      expect(
        find.byKey(const Key('study-draft-restore-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('restore-study-draft')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'unfinished answer',
      );

      await tester.enterText(find.byType(TextField), 'discard this answer');
      await tester.pump(const Duration(milliseconds: 300));
      await _repumpResume(tester, harness);
      await tester.tap(find.byKey(const Key('discard-study-draft')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
      expect(
        harness.controller.state.activeStudySession?.inputCheckpoint,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('answer duration and skill metric reach the completed summary', (
    tester,
  ) async {
    final harness = await _pumpStudy(
      tester,
      preferences: const StudyPreferences(),
      screen: const StudyScreen(mode: StudyMode.production, itemLimit: 1),
    );
    final prompt = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data!;
    final item = harness.controller.selectedItems.firstWhere(
      (candidate) => candidate.primaryTranslation == prompt,
    );

    await tester.pump(const Duration(milliseconds: 1800));
    harness.clock.value = harness.clock.value.add(
      const Duration(milliseconds: 1800),
    );
    await tester.enterText(find.byType(TextField), item.text);
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next-question-from-feedback')));
    await tester.pumpAndSettle();
    await harness.controller.flushPendingWrites();

    expect(find.textContaining('완료'), findsWidgets);
    expect(find.byKey(const Key('completion-skill-mastery')), findsOneWidget);
    final metric = harness.store.savedSessions.single.attemptMetrics.single;
    expect(metric.itemId, item.id);
    expect(metric.skill, StudySkill.writing);
    expect(metric.responseTimeMs, 1800);
    expect(metric.correct, isTrue);
  });
}

class _StudyHarness {
  _StudyHarness({
    required this.store,
    required this.controller,
    required this.screen,
    required this.clock,
  });

  final MemoryStudyStore store;
  final AppController controller;
  final ValueNotifier<Widget> screen;
  final ValueNotifier<DateTime> clock;
}

Future<_StudyHarness> _pumpStudy(
  WidgetTester tester, {
  required StudyPreferences preferences,
  required Widget screen,
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
  );
  final controller = AppController(store);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (controller.state.isHydrated) break;
    await tester.pump();
  }
  expect(controller.state.isHydrated, isTrue);
  final harness = _StudyHarness(
    store: store,
    controller: controller,
    screen: ValueNotifier(screen),
    clock: ValueNotifier(DateTime.utc(2026, 8, 3, 10)),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(harness.store),
        appControllerProvider.overrideWith((ref) => harness.controller),
        appClockProvider.overrideWithValue(() => harness.clock.value),
      ],
      child: MaterialApp(
        home: ValueListenableBuilder<Widget>(
          valueListenable: harness.screen,
          builder: (context, value, child) =>
              KeyedSubtree(key: ValueKey(value.hashCode), child: value),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _repumpResume(WidgetTester tester, _StudyHarness harness) async {
  harness.screen.value = StudyScreen(
    key: UniqueKey(),
    mode: StudyMode.production,
    resume: true,
  );
  await tester.pumpAndSettle();
}

String _textWithin(WidgetTester tester, Finder finder) => tester
    .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text)))
    .map((text) => text.data ?? '')
    .join('\n');
