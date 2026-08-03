import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/screens/session_builder_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/quick_content_sheet.dart';

const _subjectId = 'language:en';

class _QuickLauncher extends ConsumerWidget {
  const _QuickLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-compact-quick-content'),
        onPressed: ref.watch(appControllerProvider).isHydrated
            ? () => showQuickContentSheet(
                context: context,
                initialKind: LearningItemKind.word,
              )
            : null,
        child: const Text('열기'),
      ),
    ),
  );
}

LearningItem _item({
  required String id,
  required String text,
  required String meaning,
  List<String> tags = const [],
}) => LearningItem(
  id: id,
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  subjectId: _subjectId,
  text: text,
  translations: [meaning],
  acceptedAnswers: [meaning],
  partOfSpeech: PartOfSpeech.noun,
  tags: tags,
  capabilities: const {
    ExerciseCapability.recognition,
    ExerciseCapability.production,
  },
  source: ContentSource.userCreated,
);

Future<void> _pumpQuick(
  WidgetTester tester,
  MemoryStudyStore store, {
  Size size = const Size(1000, 1000),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: _QuickLauncher()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-compact-quick-content')));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryStudyStore store, {
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    tester.view.reset();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav-library')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop library opens a compact word form in one tap', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      ),
      size: const Size(1280, 900),
      platform: TargetPlatform.windows,
    );

    expect(find.byKey(const Key('library-quick-word-button')), findsOneWidget);
    expect(find.byKey(const Key('library-add-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-quick-word-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-content-core-fields-inline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-desktop-action-row')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'compact',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '간결한',
    );
    await tester.pump();
    expect(find.byKey(const Key('quick-content-clear-text')), findsOneWidget);
    expect(
      find.byKey(const Key('quick-content-clear-meaning')),
      findsOneWidget,
    );
    expect(find.text('필수 입력 완료'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-content-clear-text')));
    await tester.pump();
    final textField = tester.widget<TextFormField>(
      find.byKey(const Key('quick-content-text')),
    );
    expect(textField.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('duplicate choices stay visible while comparison is disclosed', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    await store.saveCustomItems([
      _item(id: 'compact-existing', text: 'duplicate', meaning: '중복'),
    ]);
    await _pumpQuick(tester, store);
    await tester.enterText(
      find.byKey(const Key('quick-content-text')),
      'duplicate',
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-meaning')),
      '새 뜻',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('quick-content-duplicate-notice')),
      findsOneWidget,
    );
    expect(find.text('직접 선택'), findsOneWidget);
    expect(
      find.byKey(const Key('quick-content-merge-existing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-save-separate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-duplicate-details')),
      findsNothing,
    );

    final toggle = find.byKey(
      const Key('quick-content-duplicate-details-toggle'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-content-duplicate-details')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-merge-summary-add')),
      findsOneWidget,
    );
  });

  testWidgets('recent groups and optional fields avoid repeated scrolling', (
    tester,
  ) async {
    final group = learningGroupTag('여행');
    final store = MemoryStudyStore(
      quickContentLocalPreferences: QuickContentLocalPreferences(
        recentGroupBySubject: {
          _subjectId: QuickContentRecentGroup(
            name: '여행',
            selectedAt: DateTime.utc(2026, 8, 3),
          ),
        },
      ),
    );
    await store.saveCustomItems([
      _item(
        id: 'compact-group-item',
        text: 'journey',
        meaning: '여행',
        tags: [
          group,
          learningGroupTag('업무'),
          learningGroupTag('시험'),
          learningGroupTag('회화'),
        ],
      ),
    ]);
    await _pumpQuick(tester, store);

    expect(find.byKey(const Key('quick-content-clear-group')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-content-clear-group')));
    await tester.pump();
    final recent = find.byKey(const Key('quick-content-select-recent-group'));
    expect(recent, findsOneWidget);
    await tester.tap(recent);
    await tester.pump();
    expect(find.byKey(const Key('quick-content-clear-group')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-content-clear-group')));
    await tester.pump();

    final groups = find.byKey(const Key('quick-content-group-options'));
    await tester.ensureVisible(groups);
    await tester.tap(groups);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-content-group-search')),
      '새 여행',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('quick-content-new-group-fields')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('quick-content-show-new-group')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-content-new-group-fields')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quick-content-create-group')));
    await tester.pumpAndSettle();
    expect(find.textContaining('새 여행 · 저장과 동시에 정리'), findsOneWidget);

    final details = find.byKey(const Key('quick-content-more'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-content-examples-inline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-content-preferences-inline')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('quick-content-example')),
      'A compact example.',
    );
    await tester.pump();
    expect(find.text('1개 항목 입력됨'), findsOneWidget);
  });

  testWidgets('library search and group controls expose compact context', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(
        onboardingCompleted: true,
        sessionPlan: StudySessionPlan(
          planId: 'stale-plan',
          unitIndex: 5,
          historyFilter: StudyHistoryFilter.wrongOnly,
          groupIds: {'stale-group'},
          lengthMode: StudySessionLengthMode.timeBudget,
          timeBudgetMinutes: 1,
          backlogRecovery: BacklogRecoverySettings(
            enabled: true,
            dailyLimit: 1,
          ),
        ),
      ),
    );
    await store.saveCustomItems([
      _item(
        id: 'compact-filter-route-target',
        text: 'filter-route-target',
        meaning: '필터 경로',
      ),
    ]);
    await _pumpApp(tester, store);

    expect(find.text('복습할 자료'), findsOneWidget);
    expect(find.text('즐겨찾기'), findsWidgets);
    expect(find.text('문장만'), findsOneWidget);
    expect(
      find.byKey(const Key('library-mobile-filter-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-mobile-filter-button')),
      findsOneWidget,
    );
    expect(find.textContaining('필터 · 전체 ·'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('library-select-materials'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('library-group-selection'))).dy,
        1,
      ),
    );

    await tester.enterText(
      find.byKey(const Key('library-search-field')),
      'filter-route-target',
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-search-result-count'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('active-library-filters'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('study-current-filter-results'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-clear-search'), skipOffstage: false),
      findsOneWidget,
    );
    final studyResults = find.byKey(
      const Key('study-current-filter-results'),
      skipOffstage: false,
    );
    expect(tester.widget<IconButton>(studyResults).onPressed, isNotNull);
    await tester.ensureVisible(studyResults);
    await tester.pumpAndSettle();
    await tester.tap(studyResults);
    await tester.pumpAndSettle();
    expect(find.byType(SessionBuilderScreen), findsOneWidget);
    final plan = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    ).read(appControllerProvider.notifier).activeSessionPlan;
    expect(plan.planId, isEmpty);
    expect(plan.unitIndex, isNull);
    expect(plan.historyFilter, StudyHistoryFilter.all);
    expect(plan.groupIds, isEmpty);
    expect(plan.lengthMode, StudySessionLengthMode.itemCount);
    expect(plan.timeBudgetMinutes, 5);
    expect(plan.backlogRecovery.enabled, isFalse);
    expect(plan.selectedItemIds, {'compact-filter-route-target'});
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('group dropdown keeps valid routes and clears stale routes', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        onboardingCompleted: true,
        activeSubjectId: _subjectId,
        learningGroups: [
          LearningGroupDefinition(subjectId: _subjectId, name: '여행'),
        ],
      ),
    );
    await store.saveCustomItems([
      _item(
        id: 'deep-link-group-item',
        text: 'journey',
        meaning: '여행',
        tags: [learningGroupTag('여행')],
      ),
    ]);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    });

    final container = ProviderContainer(
      overrides: [studyStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container
        .read(appRouterProvider)
        .go('/library?group=${Uri.encodeQueryComponent('여행')}');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    var dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('library-group-dropdown')),
    );
    expect(dropdown.initialValue, '여행');
    expect(
      find.byKey(const Key('library-item-deep-link-group-item')),
      findsOneWidget,
    );

    container
        .read(appRouterProvider)
        .go('/library?group=${Uri.encodeQueryComponent('삭제된 그룹')}');
    await tester.pumpAndSettle();
    dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('library-group-dropdown')),
    );
    expect(dropdown.initialValue, '');
    expect(
      find.byKey(const Key('library-item-deep-link-group-item')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('duplicate repair and result rows stay compact', (tester) async {
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    await store.saveCustomItems([
      _item(id: 'duplicate-a', text: 'repeat', meaning: '반복'),
      _item(id: 'duplicate-b', text: 'repeat', meaning: '거듭하다'),
    ]);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: LibraryScreen())),
      ),
    );
    await tester.pumpAndSettle();

    final repair = find.byKey(const Key('duplicate-repair-card'));
    expect(repair, findsOneWidget);
    expect(tester.getSize(repair).height, lessThanOrEqualTo(58));
    expect(find.byKey(const Key('open-duplicate-repair')), findsOneWidget);
    expect(find.textContaining('중복 1묶음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text uses the compact action row at medium widths', (
    tester,
  ) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await _pumpQuick(tester, MemoryStudyStore(), size: const Size(560, 900));

    expect(
      find.byKey(const Key('quick-content-desktop-action-row')),
      findsNothing,
    );
    for (final key in const [
      'quick-content-save-and-study',
      'quick-content-add-to-basket',
      'quick-content-save-and-add',
      'quick-content-save',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });
}
