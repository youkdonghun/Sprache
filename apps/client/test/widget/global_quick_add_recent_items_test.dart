import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

const _newestEnglishId = 'recent-english-newest';
const _olderEnglishId = 'recent-english-older';
const _otherSubjectId = 'recent-japanese-newer';
const _newestEnglishText = 'Newest English phrase';
const _olderEnglishText = 'Older English phrase';
const _otherSubjectText = 'Newer Japanese phrase';

List<LearningItem> _recentItems() => [
  LearningItem(
    id: _olderEnglishId,
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'language:en',
    text: _olderEnglishText,
    translations: const ['이전 영어 표현'],
    acceptedAnswers: const ['이전 영어 표현'],
    updatedAt: DateTime.utc(2026, 8, 1, 9),
  ),
  LearningItem(
    id: _newestEnglishId,
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'language:en',
    text: _newestEnglishText,
    translations: const ['가장 최근 영어 표현'],
    acceptedAnswers: const ['가장 최근 영어 표현'],
    updatedAt: DateTime.utc(2026, 8, 2, 9),
  ),
  LearningItem(
    id: _otherSubjectId,
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    subjectId: 'language:ja',
    text: _otherSubjectText,
    translations: const ['다른 주제 표현'],
    acceptedAnswers: const ['다른 주제 표현'],
    updatedAt: DateTime.utc(2026, 8, 3, 9),
  ),
];

Future<void> _withApp(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  Iterable<LearningItem> items = const [],
  double textScale = 1,
  required Future<void> Function() verify,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  try {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: 'language:en',
      ),
    );
    await store.saveCustomItems(items);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    await verify();
  } finally {
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    debugDefaultTargetPlatformOverride = null;
    tester.view.reset();
  }
}

void _expectMinimumTarget(
  WidgetTester tester,
  Finder finder,
  double minimum, {
  required String reason,
}) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(minimum), reason: reason);
  expect(size.height, greaterThanOrEqualTo(minimum), reason: reason);
}

Finder _recentTile(String itemId) => find.byKey(Key('recent-addition-$itemId'));

bool _primaryFocusIsInside(Finder finder) {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  final targets = finder.evaluate().toSet();
  if (focusedContext == null || targets.isEmpty) return false;
  if (targets.contains(focusedContext)) return true;
  var found = false;
  (focusedContext as Element).visitAncestorElements((ancestor) {
    if (!targets.contains(ancestor)) return true;
    found = true;
    return false;
  });
  return found;
}

void _requestInkWellFocus(WidgetTester tester, Finder finder) {
  final inkWell = find.descendant(of: finder, matching: find.byType(InkWell));
  final focus = find.descendant(
    of: inkWell.first,
    matching: find.byType(Focus),
  );
  final dynamic focusState = tester.state(focus.first);
  final focusNode = focusState.focusNode as FocusNode;
  focusNode.requestFocus();
}

void main() {
  for (final testCase in [
    (
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      name: 'mobile',
    ),
    (
      platform: TargetPlatform.windows,
      size: const Size(1100, 780),
      name: 'Windows',
    ),
  ]) {
    testWidgets('${testCase.name} exposes global quick add with a 44dp target', (
      tester,
    ) async {
      await _withApp(
        tester,
        platform: testCase.platform,
        size: testCase.size,
        verify: () async {
          final semantics = tester.ensureSemantics();
          try {
            final quickAdd = find.byKey(const Key('shell-quick-add'));
            expect(quickAdd, findsOneWidget);
            _expectMinimumTarget(
              tester,
              quickAdd,
              44,
              reason: '${testCase.name} global quick add must remain touchable',
            );
            final semanticsNode = tester.getSemantics(quickAdd);
            final accessibleName =
                '${semanticsNode.label} ${semanticsNode.tooltip}'.trim();
            expect(
              accessibleName,
              contains('빠른'),
              reason:
                  '${testCase.name} global quick add needs an accessible name',
            );

            await tester.tap(quickAdd);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('quick-content-sheet')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    });
  }

  testWidgets(
    'Windows Tab and F6 traversal includes quick add before Ctrl+N opens it',
    (tester) async {
      await _withApp(
        tester,
        platform: TargetPlatform.windows,
        size: const Size(1100, 780),
        verify: () async {
          _requestInkWellFocus(
            tester,
            find.byKey(const Key('open-global-search')),
          );
          await tester.pump();
          expect(
            _primaryFocusIsInside(find.byKey(const Key('open-global-search'))),
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            _primaryFocusIsInside(find.byKey(const Key('shell-quick-add'))),
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.f6);
          await tester.pump();
          expect(
            _primaryFocusIsInside(
              find.byKey(const Key('shell-main-content-focus')),
            ),
            isTrue,
          );
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets('home quick add exposes save confirmation and undo', (
    tester,
  ) async {
    await _withApp(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(1100, 780),
      verify: () async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final controller = container.read(appControllerProvider.notifier);
        final dataFlow = find.byKey(const Key('learning-data-flow-card'));
        final addStep = find.descendant(
          of: dataFlow,
          matching: find.text('자료 추가'),
        );
        await tester.ensureVisible(addStep);
        await tester.pumpAndSettle();
        await tester.tap(addStep);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('quick-content-text')),
          'home undo phrase',
        );
        await tester.enterText(
          find.byKey(const Key('quick-content-meaning')),
          '홈 실행 취소 표현',
        );
        await tester.tap(find.byKey(const Key('quick-content-save')));
        await tester.pumpAndSettle();

        final saved = controller.state.customItems.singleWhere(
          (item) => item.text == 'home undo phrase',
        );
        expect(find.text('“home undo phrase” 자료를 저장했습니다.'), findsOneWidget);
        expect(find.text('실행 취소'), findsOneWidget);

        await tester.tap(find.text('실행 취소'));
        await tester.pumpAndSettle();
        expect(controller.customItemById(saved.id), isNull);
        expect(find.text('마지막 저장을 되돌렸습니다.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('global quick add save-and-study opens the selected item plan', (
    tester,
  ) async {
    await _withApp(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      verify: () async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final controller = container.read(appControllerProvider.notifier);

        await tester.tap(find.byKey(const Key('shell-quick-add')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('quick-content-text')),
          'study this phrase',
        );
        await tester.enterText(
          find.byKey(const Key('quick-content-meaning')),
          '바로 학습할 표현',
        );
        await tester.tap(find.byKey(const Key('quick-content-save-and-study')));
        await tester.pumpAndSettle();

        final saved = controller.state.customItems.singleWhere(
          (item) => item.text == 'study this phrase',
        );
        final plan = controller.activeSessionPlan;
        expect(find.byKey(const Key('session-builder-scroll')), findsOneWidget);
        expect(plan.deck, StudyDeckScope.selected);
        expect(plan.selectedItemIds, {saved.id});
        expect(plan.itemLimit, 1);
        expect(find.text('“study this phrase” 자료를 저장했습니다.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'recent additions shows newest active-subject items and opens edit',
    (tester) async {
      await _withApp(
        tester,
        platform: TargetPlatform.android,
        size: const Size(390, 844),
        items: _recentItems(),
        verify: () async {
          final tray = find.byKey(const Key('recent-additions-tray'));
          expect(tray, findsOneWidget);
          final tiles = tester
              .widgetList<ListTile>(
                find.descendant(of: tray, matching: find.byType(ListTile)),
              )
              .toList(growable: false);
          expect(tiles, hasLength(2));
          expect(tiles.map((tile) => (tile.title! as Text).data), [
            _newestEnglishText,
            _olderEnglishText,
          ]);
          expect(find.text(_otherSubjectText), findsNothing);

          final newestTile = _recentTile(_newestEnglishId);
          _expectMinimumTarget(
            tester,
            newestTile,
            48,
            reason: 'A recent item row must remain an accessible edit target',
          );
          await tester.ensureVisible(newestTile);
          await tester.pumpAndSettle();
          await tester.tap(newestTile);
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets('recent additions play callback starts one-item study', (
    tester,
  ) async {
    await _withApp(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      items: _recentItems(),
      verify: () async {
        final newestTile = _recentTile(_newestEnglishId);
        final actions = find.descendant(
          of: newestTile,
          matching: find.byType(IconButton),
        );
        expect(actions, findsNWidgets(2));
        _expectMinimumTarget(
          tester,
          actions.at(0),
          48,
          reason: 'The recent-item play action must remain a 48dp target',
        );
        await tester.ensureVisible(newestTile);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('$_newestEnglishText 바로 학습'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('study-screen')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('recent additions trash exposes a reachable undo callback', (
    tester,
  ) async {
    await _withApp(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      items: _recentItems(),
      verify: () async {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final controller = container.read(appControllerProvider.notifier);
        final newestTile = _recentTile(_newestEnglishId);
        final actions = find.descendant(
          of: newestTile,
          matching: find.byType(IconButton),
        );
        _expectMinimumTarget(
          tester,
          actions.at(1),
          48,
          reason: 'The recent-item trash action must remain a 48dp target',
        );

        await tester.ensureVisible(newestTile);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('$_newestEnglishText 휴지통으로 이동'));
        await tester.pumpAndSettle();
        expect(controller.customItemById(_newestEnglishId), isNull);
        expect(_recentTile(_newestEnglishId), findsNothing);

        final undo = find.text('실행 취소');
        expect(undo, findsOneWidget);
        await tester.tap(undo);
        await tester.pumpAndSettle();
        expect(controller.customItemById(_newestEnglishId), isNotNull);
        expect(_recentTile(_newestEnglishId), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('recent additions stay overflow-free at 200% text', (
    tester,
  ) async {
    await _withApp(
      tester,
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      items: _recentItems(),
      textScale: 2,
      verify: () async {
        final tray = find.byKey(const Key('recent-additions-tray'));
        final olderTile = _recentTile(_olderEnglishId);
        expect(tray, findsOneWidget);
        expect(olderTile, findsOneWidget);
        await tester.ensureVisible(olderTile);
        await tester.pumpAndSettle();

        expect(find.text(_newestEnglishText), findsOneWidget);
        expect(find.text(_olderEnglishText), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
