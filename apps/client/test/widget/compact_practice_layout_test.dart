import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/flashcard_screen.dart';
import 'package:sprache/src/screens/mission_screen.dart';
import 'package:sprache/src/screens/pronunciation_screen.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('short quiz choices use a compact ordered grid', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final semantics = tester.ensureSemantics();

    try {
      await _pumpScreen(
        tester,
        const StudyScreen(mode: StudyMode.meaning, itemLimit: 5),
      );

      expect(find.byKey(const Key('study-choice-grid')), findsOneWidget);
      for (var index = 0; index < 4; index++) {
        expect(
          tester.getSize(find.byKey(Key('study-choice-$index'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'1/5 문제, 정답 0개, 오답 0개, 현재 0콤보, '
            r'연속 목표 3개, 획득 0 XP',
          ),
        ),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(320, 900);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('study-choice-single-column')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('flashcard sizes to content and expands safely', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await _pumpScreen(
        tester,
        const FlashcardScreen(kind: FlashcardKind.words),
      );

      final compactCard = find.byKey(const Key('compact-flashcard-content'));
      expect(compactCard, findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(tester.getSize(compactCard).height, lessThan(330));

      tester.view.physicalSize = const Size(320, 900);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('pronunciation keeps scoring help collapsed until requested', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await _pumpScreen(tester, const PronunciationScreen());

      final panel = find.byKey(const Key('pronunciation-recognition-panel'));
      expect(panel, findsOneWidget);
      expect(tester.getSize(panel).height, lessThan(180));
      expect(find.textContaining('억양이나 개별 음소').hitTestable(), findsNothing);

      await tester.tap(find.text('점수는 어떻게 계산하나요?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('억양이나 개별 음소').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('mission briefing reveals guide only on demand', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    try {
      await _pumpScreen(tester, const MissionPracticeScreen(unitIndex: 0));

      expect(
        find.byKey(const Key('mission-briefing-disclosure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mission-open-unit-guide')).hitTestable(),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('mission-briefing-disclosure')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mission-open-unit-guide')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}
