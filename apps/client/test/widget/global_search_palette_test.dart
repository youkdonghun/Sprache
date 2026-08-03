import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
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
    return ProviderScope.containerOf(tester.element(find.byType(SpracheApp)));
  }

  testWidgets('Android top search opens and finds another subject', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final controller = container.read(appControllerProvider.notifier);
    final japaneseItem = controller.allContentItems.firstWhere(
      (item) => item.learningLanguage == LanguageTag.japanese,
    );
    final searchButton = find.byKey(const Key('open-global-search'));
    expect(searchButton, findsOneWidget);
    expect(tester.getSize(searchButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(searchButton).height, greaterThanOrEqualTo(44));

    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-search-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('global-search-field')),
      japaneseItem.text,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-search-results')), findsOneWidget);
    final resultText = find.descendant(
      of: find.byKey(const Key('global-search-results')),
      matching: find.text(japaneseItem.text),
    );
    expect(resultText, findsOneWidget);

    await tester.tap(resultText);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(
      container.read(appControllerProvider).selectedLanguage,
      LanguageTag.japanese,
    );
    final queryField = tester.widget<TextField>(
      find.byKey(const Key('library-search-field'), skipOffstage: false),
    );
    expect(queryField.controller?.text, japaneseItem.text);
    expect(tester.takeException(), isNull);
  });
}
