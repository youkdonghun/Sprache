import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/screens/settings_screen.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  Future<void> withDesktopApp(
    WidgetTester tester,
    Future<void> Function() verify,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
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
      await verify();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  }

  Future<void> pressCommandShortcut(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('desktop exposes Ctrl+K and finds the storage deep link', (
    tester,
  ) async {
    await withDesktopApp(tester, () async {
      expect(find.text('명령 · Ctrl K'), findsOneWidget);
      await pressCommandShortcut(tester);

      expect(find.byKey(const Key('global-search-field')), findsOneWidget);
      expect(
        find.byKey(const Key('command-palette-quick-add')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('global-search-field')),
        'drive',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('command-palette-storage-settings')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('command-palette-storage-settings')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      final context = tester.element(find.byType(SettingsScreen));
      expect(
        GoRouter.of(context).routeInformationProvider.value.uri.queryParameters,
        containsPair('focus', 'storage'),
      );
    });
  });

  testWidgets('quick-add command opens the registration sheet', (tester) async {
    await withDesktopApp(tester, () async {
      await tester.tap(find.byKey(const Key('open-global-search')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('command-palette-quick-add')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Enter runs the highest ranked keyboard command', (tester) async {
    await withDesktopApp(tester, () async {
      await pressCommandShortcut(tester);

      await tester.enterText(
        find.byKey(const Key('global-search-field')),
        '자료실',
      );
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global-search-field')), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });

  testWidgets('arrow keys select a command before Enter runs it', (
    tester,
  ) async {
    await withDesktopApp(tester, () async {
      await pressCommandShortcut(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final libraryTile = tester.widget<ListTile>(
        find.byKey(const Key('command-palette-library')),
      );
      expect(libraryTile.selected, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });

  testWidgets('game command enters through the hub availability coordinator', (
    tester,
  ) async {
    await withDesktopApp(tester, () async {
      await pressCommandShortcut(tester);
      await tester.enterText(
        find.byKey(const Key('global-search-field')),
        '뜻 고르기',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('command-palette-meaning-choice')));
      await tester.pumpAndSettle();

      expect(find.byType(StudyScreen), findsOneWidget);
      expect(
        tester.widget<StudyScreen>(find.byType(StudyScreen)).practiceActivityId,
        'meaning-choice',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
