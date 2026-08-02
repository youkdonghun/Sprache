import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('F6 moves Windows navigation focus to the main content', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.pump();

      final contentFocus = tester.widget<Focus>(
        find.byKey(const Key('shell-main-content-focus')),
      );
      expect(contentFocus.focusNode?.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Ctrl+F focuses library search and Escape clears it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);

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

      final searchFinder = find.byKey(const Key('library-search-field'));
      final search = tester.widget<TextField>(searchFinder);
      expect(search.focusNode?.hasFocus, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(search.focusNode?.hasFocus, isTrue);

      await tester.enterText(searchFinder, 'water');
      await tester.pump();
      expect(find.text('water'), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(tester.widget<TextField>(searchFinder).controller?.text, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('typed-answer mode reserves plain Space for the answer', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);

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
      await tester.ensureVisible(find.text('직접 쓰기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 쓰기'));
      await tester.pumpAndSettle();
      final startSession = find.byKey(const Key('start-practice-session'));
      await tester.ensureVisible(startSession);
      await tester.pumpAndSettle();
      await tester.tap(startSession);
      await tester.pumpAndSettle();

      final shortcuts = tester.widget<CallbackShortcuts>(
        find.byKey(const Key('study-screen')),
      );
      expect(
        shortcuts.bindings,
        isNot(contains(const SingleActivator(LogicalKeyboardKey.space))),
      );
      expect(
        shortcuts.bindings,
        contains(
          const SingleActivator(LogicalKeyboardKey.space, control: true),
        ),
      );
      expect(find.text('Enter 제출 · Ctrl+Space 발음 다시 듣기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('arrow and Enter solve a choice question without a mouse', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);
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
      await tester.ensureVisible(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('뜻 고르기'));
      await tester.pumpAndSettle();
      final startSession = find.byKey(const Key('start-practice-session'));
      await tester.ensureVisible(startSession);
      await tester.pumpAndSettle();
      await tester.tap(startSession);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('다음 문제'), findsOneWidget);
      expect(find.byKey(const Key('study-feedback-popup')), findsOneWidget);
      final popupSize = tester.getSize(
        find.byKey(const Key('study-feedback-popup')),
      );
      expect(popupSize.width, lessThanOrEqualTo(420));
      expect(popupSize.height, lessThanOrEqualTo(560));
      expect(store.savedEvents, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(store.savedEvents, hasLength(1));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('numpad rating advances flashcards', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 720);
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
      await tester.ensureVisible(find.text('단어 카드'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('단어 카드'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flashcard-remembered')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
      await tester.pumpAndSettle();

      expect(store.savedEvents, hasLength(1));
      expect(store.savedEvents.single.exerciseType, 'flashcard_good');
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
