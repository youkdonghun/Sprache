import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/search_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  LearningItem item(int index, String prefix) => LearningItem(
    id: '${prefix.replaceAll(' ', '-')}-$index',
    kind: index.isEven ? LearningItemKind.word : LearningItemKind.sentence,
    learningLanguage: LanguageTag.english,
    subjectId: 'language:en',
    text: '$prefix ${index.toString().padLeft(3, '0')}',
    translations: ['테스트 뜻 $index'],
    acceptedAnswers: ['테스트 뜻 $index'],
  );

  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester, {
    required MemoryStudyStore store,
    required Size size,
    required TargetPlatform platform,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    });
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

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('library-search-field'), skipOffstage: false),
      query,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets(
      '${platform.name} keeps a master-detail selection across all view modes',
      (tester) async {
        final store = MemoryStudyStore(
          preferences: const StudyPreferences(onboardingCompleted: true),
        );
        await store.saveCustomItems([
          item(1, 'desktop pair'),
          item(2, 'desktop pair'),
        ]);
        await pumpLibrary(
          tester,
          store: store,
          size: const Size(1280, 950),
          platform: platform,
        );

        expect(
          find.byKey(const Key('desktop-library-master-detail')),
          findsOneWidget,
        );
        await search(tester, 'desktop pair');
        expect(
          find.byKey(const Key('library-results-spacious-page-0')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('library-item-desktop-pair-2')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('desktop-library-detail-desktop-pair-2')),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.density_small_rounded));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('library-results-compact-page-0')),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.grid_view_rounded));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('library-results-grid-page-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('desktop-library-detail-desktop-pair-2')),
          findsOneWidget,
        );

        await search(tester, 'desktop pair 001');
        expect(
          find.byKey(const Key('desktop-library-detail-desktop-pair-2')),
          findsOneWidget,
          reason: 'detail selection should survive a filter that hides its row',
        );
        expect(
          (await store.loadSearchLocalPreferences()).libraryViewMode,
          LibraryViewMode.grid,
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('mobile details move to the previous and next filtered item', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    await store.saveCustomItems([
      item(1, 'mobile sequence'),
      item(2, 'mobile sequence'),
    ]);
    await pumpLibrary(
      tester,
      store: store,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    await search(tester, 'mobile sequence');

    await tester.tap(find.byKey(const Key('library-item-mobile-sequence-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-library-detail-mobile-sequence-1')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-detail-next')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-library-detail-mobile-sequence-2')),
      findsOneWidget,
    );
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-detail-previous')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-library-detail-mobile-sequence-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'bulk selection covers page, filter, inversion and hidden count',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      );
      await store.saveCustomItems([
        for (var index = 0; index < 45; index++) item(index, 'bulk material'),
      ]);
      await pumpLibrary(
        tester,
        store: store,
        size: const Size(820, 950),
        platform: TargetPlatform.android,
      );
      await search(tester, 'bulk material');
      expect(find.textContaining('1/2 화면'), findsOneWidget);

      final selectMaterials = find.byKey(const Key('library-select-materials'));
      await tester.ensureVisible(selectMaterials);
      await tester.tap(selectMaterials);
      await tester.pumpAndSettle();
      final selectCurrentPage = find.byKey(
        const Key('library-select-current-page'),
      );
      await tester.ensureVisible(selectCurrentPage);
      await tester.tap(selectCurrentPage);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택 40개'), findsWidgets);

      final nextPage = tester.widget<IconButton>(
        find.byKey(const Key('library-result-next-page')),
      );
      expect(nextPage.onPressed, isNotNull);
      nextPage.onPressed!();
      await tester.pumpAndSettle();
      expect(find.textContaining('현재 화면 밖 40개'), findsOneWidget);
      await tester.ensureVisible(selectCurrentPage);
      await tester.tap(selectCurrentPage);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택 45개'), findsWidgets);

      await search(tester, 'bulk material 044');
      expect(find.textContaining('필터 밖 44개'), findsWidgets);
      final invertFiltered = find.byKey(
        const Key('library-invert-filtered-selection'),
      );
      await tester.ensureVisible(invertFiltered);
      await tester.tap(invertFiltered);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택 44개'), findsWidgets);
      final selectFiltered = find.byKey(const Key('library-select-filtered'));
      await tester.ensureVisible(selectFiltered);
      await tester.tap(selectFiltered);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택 45개'), findsWidgets);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'desktop supports context menu and command/shift range selection',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      );
      await store.saveCustomItems([
        item(1, 'desktop select'),
        item(2, 'desktop select'),
        item(3, 'desktop select'),
      ]);
      await pumpLibrary(
        tester,
        store: store,
        size: const Size(1280, 950),
        platform: TargetPlatform.windows,
      );
      await search(tester, 'desktop select');

      final first = find.byKey(const Key('library-item-desktop-select-1'));
      await tester.tap(first, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(find.text('수정'), findsOneWidget);
      expect(find.text('그룹에 넣기'), findsOneWidget);
      expect(find.text('이 자료 학습'), findsOneWidget);
      expect(find.text('내보내기'), findsOneWidget);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(first);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byKey(const Key('library-item-desktop-select-3')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택 3개'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.textContaining('선택을 해제했습니다'), findsOneWidget);
      expect(find.textContaining('선택 3개'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
