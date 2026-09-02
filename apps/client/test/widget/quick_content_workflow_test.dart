import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/state/app_state.dart';

Future<void> _pumpAppAndOpenQuickWord(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
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
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'add menu transition stays overflow-free at 390x844 in ${brightness.name}',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;
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
          await tester.tap(find.byKey(const Key('nav-library')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('library-add-button')));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('add-content-menu-scroll')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('add-language-pack')), findsOneWidget);
          await tester.tap(find.byKey(const Key('add-quick-word')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
          tester.view.reset();
        }
      },
    );
  }

  testWidgets('quick add keeps the user in one clear add-group-learn flow', (
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
      await tester.tap(find.byKey(const Key('nav-library')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('learning-data-flow-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-add-button')));
      await tester.pumpAndSettle();
      expect(find.text('무엇을 추가할까요?'), findsOneWidget);

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
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-group-options')),
      );
      await tester.tap(find.byKey(const Key('quick-content-group-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-content-show-new-group')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('quick-content-new-group')),
        '업무',
      );
      await tester.tap(find.byKey(const Key('quick-content-create-group')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-content-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('quick-content-unsaved-dialog')),
        findsNothing,
      );
      expect(find.byKey(const Key('saved-content-add-more')), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      final controller = container.read(appControllerProvider.notifier);
      expect(
        controller.courseItems.where((item) => item.text == 'workaround'),
        hasLength(1),
      );
      expect(controller.itemsForLearningGroup('업무'), isNotEmpty);

      await tester.tap(find.byKey(const Key('saved-content-add-more')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('quick-content-text')),
        'workaround',
      );
      await tester.enterText(
        find.byKey(const Key('quick-content-meaning')),
        '임시 해결책',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('quick-content-duplicate-notice')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets(
    'quick add closes an empty sheet and confirms dirty close or system back',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      try {
        await _pumpAppAndOpenQuickWord(tester);

        await tester.tap(find.byKey(const Key('quick-content-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quick-content-sheet')), findsNothing);
        expect(
          find.byKey(const Key('quick-content-unsaved-dialog')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('library-add-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('add-quick-word')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('quick-content-text')),
          'unfinished',
        );

        await tester.tap(find.byKey(const Key('quick-content-close')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('quick-content-unsaved-dialog')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('quick-content-keep-editing')));
        await tester.pumpAndSettle();
        expect(find.text('unfinished'), findsOneWidget);
        expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('quick-content-unsaved-dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('quick-content-discard-and-exit')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('quick-content-sheet')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );

  testWidgets('quick add draft guards bottom tab changes', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await _pumpAppAndOpenQuickWord(tester);
      await tester.enterText(
        find.byKey(const Key('quick-content-meaning')),
        '작성 중인 뜻',
      );

      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('quick-content-unsaved-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('quick-content-keep-editing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
      expect(find.text('작성 중인 뜻'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-content-discard-and-exit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick-content-sheet')), findsNothing);
      expect(find.byKey(const Key('nav-home')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
