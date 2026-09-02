import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/search_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/global_search_palette.dart';
import 'package:sprache/src/widgets/highlighted_search_text.dart';

class _GlobalSearchHarness extends ConsumerWidget {
  const _GlobalSearchHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-test-search'),
          onPressed: () => showGlobalSearchPalette(context, ref),
          child: const Text('검색'),
        ),
      ),
    );
  }
}

void main() {
  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester,
    MemoryStudyStore store,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: LibraryScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(LibraryScreen)),
    );
  }

  Future<ProviderContainer> pumpGlobalSearch(
    WidgetTester tester,
    MemoryStudyStore store,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: _GlobalSearchHarness()),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_GlobalSearchHarness)),
    );
    await tester.tap(find.byKey(const Key('open-test-search')));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('library shows, applies, stores and deletes subject history', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
      searchLocalPreferences: const SearchLocalPreferences(
        recentBySubject: {
          'language:en': ['type:sentence'],
        },
      ),
    );
    await pumpLibrary(tester, store);

    final recent = find.byKey(
      const Key('library-recent-search-type:sentence'),
      skipOffstage: false,
    );
    expect(recent, findsOneWidget);
    expect(
      find.byKey(const Key('library-search-suggestion-state:due')),
      findsNothing,
    );

    await tester.tap(recent);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('library-search-field'), skipOffstage: false),
    );
    expect(field.controller?.text, 'type:sentence');

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.close_rounded, skipOffstage: false),
            matching: find.byType(IconButton, skipOffstage: false),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final chip = tester.widget<InputChip>(recent);
    chip.onDeleted!();
    await tester.pumpAndSettle();

    expect(recent, findsNothing);
    expect(
      (await store.loadSearchLocalPreferences()).recentForSubject(
        'language:en',
      ),
      isEmpty,
    );
  });

  testWidgets('library offers a local typo suggestion and applies it', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    final container = await pumpLibrary(tester, store);
    final item = container
        .read(appControllerProvider.notifier)
        .courseItems
        .firstWhere(
          (candidate) =>
              candidate.text.length >= 6 &&
              !candidate.text.contains(RegExp(r'\s')),
        );
    final typo = '${item.text.substring(0, item.text.length - 1)}x';

    await tester.enterText(find.byKey(const Key('library-search-field')), typo);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final suggestion = find.byKey(Key('library-similar-search-${item.text}'));
    expect(suggestion, findsOneWidget);

    await tester.tap(suggestion);
    await tester.pumpAndSettle();
    expect(find.byKey(Key('library-item-${item.id}')), findsOneWidget);
  });

  testWidgets('global palette exposes history, suggestions and grouping', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
      searchLocalPreferences: const SearchLocalPreferences(
        globalRecent: ['bonjour'],
      ),
    );
    await pumpGlobalSearch(tester, store);

    expect(
      find.byKey(const Key('global-recent-search-bonjour')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('global-search-suggestion-state:due')),
      findsOneWidget,
    );
    final recent = tester.widget<InputChip>(
      find.byKey(const Key('global-recent-search-bonjour')),
    );
    recent.onDeleted!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-recent-search-bonjour')), findsNothing);

    await tester.tap(
      find.byKey(const Key('global-search-suggestion-type:sentence')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('global-search-layout-toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'global-search-group-',
            ),
      ),
      findsWidgets,
    );
  });

  testWidgets('global result highlights a match and suggests typo recovery', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    final container = await pumpGlobalSearch(tester, store);
    final item = container
        .read(appControllerProvider.notifier)
        .allContentItems
        .firstWhere(
          (candidate) =>
              candidate.text.length >= 6 &&
              !candidate.text.contains(RegExp(r'\s')),
        );

    await tester.enterText(
      find.byKey(const Key('global-search-field')),
      item.text,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<HighlightedSearchText>(find.byType(HighlightedSearchText))
          .where((widget) => widget.text == item.text),
      isNotEmpty,
    );

    final typo = '${item.text.substring(0, item.text.length - 1)}x';
    await tester.enterText(find.byKey(const Key('global-search-field')), typo);
    await tester.pumpAndSettle();
    final suggestion = find.byKey(Key('global-search-similar-${item.text}'));
    expect(suggestion, findsOneWidget);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global-search-results')), findsOneWidget);
  });
}
