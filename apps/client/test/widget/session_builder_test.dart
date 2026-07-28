import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
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
      await tester.tap(find.text('자유 학습'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-session-builder')));
      await tester.pumpAndSettle();

      expect(find.text('나만의 학습 세션'), findsOneWidget);
      expect(find.text('10문제 시작'), findsNWidgets(2));

      await tester.ensureVisible(find.byKey(const Key('session-deck-unit')));
      await tester.tap(find.byKey(const Key('session-deck-unit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('session-include-sentences')),
      );
      await tester.tap(find.byKey(const Key('session-include-sentences')));
      await tester.tap(find.byKey(const Key('session-limit-5')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('session-save-bottom')));
      await tester.tap(find.byKey(const Key('session-save-bottom')));
      await tester.pump(const Duration(milliseconds: 30));

      expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.unit);
      expect(store.savedPreferences.sessionPlan.includeWords, isTrue);
      expect(store.savedPreferences.sessionPlan.includeSentences, isFalse);
      expect(store.savedPreferences.sessionPlan.itemLimit, 5);

      await tester.tap(find.byKey(const Key('session-start-bottom')));
      await tester.pumpAndSettle();

      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'학습 진행 1/5')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  for (final size in const [Size(375, 812), Size(430, 932), Size(1024, 720)]) {
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
        await tester.tap(find.text('자유 학습'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-session-builder')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const Key('session-builder-scroll')),
          const Offset(0, -2200),
        );
        await tester.pumpAndSettle();

        expect(find.text('레벨과 태그'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}
