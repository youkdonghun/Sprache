import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_draft.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/widgets/quick_content_sheet.dart';

const _subjectId = 'language:en';

class _QuickContentLauncher extends ConsumerWidget {
  const _QuickContentLauncher({this.initialKind});

  final LearningItemKind? initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(appControllerProvider).isHydrated;
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-quick-content'),
          onPressed: !hydrated
              ? null
              : () => showQuickContentSheet(
                  context: context,
                  initialKind: initialKind,
                ),
          child: const Text('빠른 등록 열기'),
        ),
      ),
    );
  }
}

class _DelayedQuickLoadStore extends MemoryStudyStore {
  _DelayedQuickLoadStore({
    required this.delayedDraft,
    required this.delayedPreferences,
    required super.preferences,
  }) : super(
         quickContentDraft: delayedDraft,
         quickContentLocalPreferences: delayedPreferences,
       );

  final QuickContentDraft delayedDraft;
  final QuickContentLocalPreferences delayedPreferences;
  final _draftGate = Completer<QuickContentDraft?>();
  final _preferenceGate = Completer<QuickContentLocalPreferences>();
  var _draftLoadCount = 0;
  var _preferenceLoadCount = 0;

  void releaseQuickLoads() {
    if (!_draftGate.isCompleted) _draftGate.complete(delayedDraft);
    if (!_preferenceGate.isCompleted) {
      _preferenceGate.complete(delayedPreferences);
    }
  }

  @override
  Future<QuickContentDraft?> loadQuickContentDraft() {
    _draftLoadCount++;
    return _draftLoadCount == 1
        ? _draftGate.future
        : super.loadQuickContentDraft();
  }

  @override
  Future<QuickContentLocalPreferences> loadQuickContentLocalPreferences() {
    _preferenceLoadCount++;
    return _preferenceLoadCount == 1
        ? _preferenceGate.future
        : super.loadQuickContentLocalPreferences();
  }
}

StudyPreferences _studyPreferences(AppExperiencePreferences experience) =>
    StudyPreferences(
      onboardingCompleted: true,
      activeSubjectId: _subjectId,
      experience: experience,
    );

Future<void> _pumpAndOpen(
  WidgetTester tester,
  MemoryStudyStore store, {
  LearningItemKind? initialKind,
  bool settleAfterOpen = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1100);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: MaterialApp(home: _QuickContentLauncher(initialKind: initialKind)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-quick-content')));
  if (settleAfterOpen) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

LearningItemKind _selectedKind(WidgetTester tester) => tester
    .widget<SegmentedButton<LearningItemKind>>(
      find.byKey(const Key('quick-content-kind')),
    )
    .selected
    .single;

Future<void> _enterRequired(
  WidgetTester tester, {
  required String text,
  required String meaning,
}) async {
  await tester.enterText(find.byKey(const Key('quick-content-text')), text);
  await tester.enterText(
    find.byKey(const Key('quick-content-meaning')),
    meaning,
  );
  await tester.pump();
}

void main() {
  for (final testCase in const [
    (AppDuplicateDefault.ask, 1, false),
    (AppDuplicateDefault.merge, 1, true),
    (AppDuplicateDefault.separate, 2, true),
  ]) {
    testWidgets(
      '${testCase.$1.name} duplicate default is applied without a hidden fallback',
      (tester) async {
        const existing = LearningItem(
          id: 'personalized-duplicate-existing',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          subjectId: _subjectId,
          text: 'audit duplicate',
          translations: ['기존 뜻'],
          acceptedAnswers: ['기존 뜻'],
          partOfSpeech: PartOfSpeech.noun,
        );
        final store = MemoryStudyStore(
          preferences: _studyPreferences(
            AppExperiencePreferences(duplicateDefault: testCase.$1),
          ),
        );
        await store.saveCustomItems(const [existing]);
        await _pumpAndOpen(tester, store);
        await _enterRequired(tester, text: existing.text, meaning: '새 뜻');
        await tester.tap(find.byKey(const Key('quick-content-save')));
        await tester.pumpAndSettle();

        expect(store.savedItems, hasLength(testCase.$2));
        if (testCase.$3) {
          expect(find.byKey(const Key('quick-content-sheet')), findsNothing);
        } else {
          expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
          expect(find.textContaining('뜻 병합이나 별도 저장'), findsOneWidget);
        }
        if (testCase.$1 == AppDuplicateDefault.merge) {
          expect(store.savedItems.single.id, existing.id);
          expect(
            store.savedItems.single.translations,
            containsAll(['기존 뜻', '새 뜻']),
          );
        }
        if (testCase.$1 == AppDuplicateDefault.separate) {
          expect(store.savedItems.map((item) => item.id).toSet(), hasLength(2));
          expect(
            store.savedItems.where((item) => item.text == existing.text),
            hasLength(2),
          );
        }
      },
    );
  }

  testWidgets(
    'sentence default, expanded details, and required progress react in the sheet',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: _studyPreferences(
          const AppExperiencePreferences(
            quickAddKind: AppQuickAddKind.sentence,
            quickAddOpenDetails: true,
          ),
        ),
      );
      await _pumpAndOpen(tester, store);

      expect(_selectedKind(tester), LearningItemKind.sentence);
      expect(find.byKey(const Key('quick-content-example')), findsOneWidget);
      expect(find.text('필수 입력 0 / 2'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('quick-content-text')),
        'A complete sentence.',
      );
      await tester.pump();
      expect(find.text('필수 입력 1 / 2'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('quick-content-meaning')),
        '완전한 문장',
      );
      await tester.pump();
      expect(find.text('필수 입력 완료'), findsOneWidget);
      final semantics = tester.getSemantics(
        find.byKey(const Key('quick-content-required-progress')),
      );
      expect(semantics.label, contains('2개 중 2개 완료'));
    },
  );

  testWidgets(
    'favorite and priority defaults are persisted in the saved item',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: _studyPreferences(
          const AppExperiencePreferences(
            quickAddOpenDetails: true,
            quickAddFavoriteDefault: true,
            quickAddPriorityDefault: 4,
          ),
        ),
      );
      await _pumpAndOpen(tester, store);

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('quick-content-favorite')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Slider>(find.byKey(const Key('quick-content-priority')))
            .value,
        4,
      );
      await _enterRequired(
        tester,
        text: 'personalized-priority-item',
        meaning: '개인화 우선순위 자료',
      );
      await tester.tap(find.byKey(const Key('quick-content-save')));
      await tester.pumpAndSettle();

      expect(store.savedItems, hasLength(1));
      final saved = store.savedItems.single;
      expect(saved.priority, 4);
      expect(store.savedPreferences.favoriteItemIds, contains(saved.id));
    },
  );

  testWidgets('automatic normalization applies Unicode NFKC and whitespace', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: _studyPreferences(
        const AppExperiencePreferences(quickAddAutoNormalize: true),
      ),
    );
    await _pumpAndOpen(tester, store);
    await _enterRequired(
      tester,
      text: '  Ｈｅｌｌｏ　   world  ',
      meaning: '  인사　   표현  ',
    );
    await tester.tap(find.byKey(const Key('quick-content-save')));
    await tester.pumpAndSettle();

    expect(store.savedItems, hasLength(1));
    expect(store.savedItems.single.text, 'Hello world');
    expect(store.savedItems.single.translations, const ['인사 표현']);
  });

  testWidgets(
    'keep-adding default remembers tags and offers them on the next opening',
    (tester) async {
      final store = MemoryStudyStore(
        preferences: _studyPreferences(
          const AppExperiencePreferences(
            quickAddOpenDetails: true,
            quickAddKeepAddingDefault: true,
            quickAddRememberTags: true,
          ),
        ),
      );
      await _pumpAndOpen(tester, store);
      await _enterRequired(
        tester,
        text: 'first-keep-adding-item',
        meaning: '첫 계속 등록 자료',
      );
      await tester.ensureVisible(find.byKey(const Key('quick-content-tags')));
      await tester.enterText(
        find.byKey(const Key('quick-content-tags')),
        '여행, 회화',
      );
      await tester.ensureVisible(
        find.byKey(const Key('quick-content-save-and-add')),
      );
      await tester.tap(find.byKey(const Key('quick-content-save-and-add')));
      await tester.pumpAndSettle();

      expect(store.savedItems, hasLength(1));
      expect(find.byKey(const Key('quick-content-sheet')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('quick-content-text')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('quick-content-tags')))
            .controller
            ?.text,
        '여행, 회화',
      );
      final preferences = await store.loadQuickContentLocalPreferences();
      expect(preferences.lastKindBySubject[_subjectId], LearningItemKind.word);
      expect(preferences.recentTagsBySubject[_subjectId], const ['여행', '회화']);

      await tester.tap(find.byKey(const Key('quick-content-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-quick-content')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('quick-content-recent-tags')),
        findsOneWidget,
      );
      expect(find.widgetWithText(ActionChip, '여행'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '회화'), findsOneWidget);
    },
  );

  testWidgets('last-used kind is restored from device-local preferences', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: _studyPreferences(
        const AppExperiencePreferences(quickAddKind: AppQuickAddKind.lastUsed),
      ),
      quickContentLocalPreferences: const QuickContentLocalPreferences(
        lastKindBySubject: {_subjectId: LearningItemKind.sentence},
      ),
    );
    await _pumpAndOpen(tester, store);

    expect(_selectedKind(tester), LearningItemKind.sentence);
  });

  testWidgets(
    'early user input wins over delayed preferences and draft recovery loads',
    (tester) async {
      final delayedDraft = QuickContentDraft(
        subjectId: _subjectId,
        kind: LearningItemKind.sentence,
        text: 'stale delayed draft',
        meanings: const ['오래된 지연 초안'],
        acceptedAnswers: const [],
        readings: const {},
        sentenceTokens: const ['stale', 'delayed', 'draft'],
        example: '',
        exampleMeaning: '',
        partOfSpeech: PartOfSpeech.noun,
        group: null,
        tags: const [],
        favorite: false,
        priority: 0,
        updatedAt: DateTime.utc(2026, 8, 2),
      );
      const delayedPreferences = QuickContentLocalPreferences(
        lastKindBySubject: {_subjectId: LearningItemKind.sentence},
      );
      final store = _DelayedQuickLoadStore(
        delayedDraft: delayedDraft,
        delayedPreferences: delayedPreferences,
        preferences: _studyPreferences(
          const AppExperiencePreferences(
            quickAddKind: AppQuickAddKind.lastUsed,
            quickAddDraftDelayMs: 200,
          ),
        ),
      );
      await _pumpAndOpen(tester, store, settleAfterOpen: false);
      await _enterRequired(
        tester,
        text: 'fresh early input',
        meaning: '사용자 조기 입력',
      );

      store.releaseQuickLoads();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.text('fresh early input'), findsOneWidget);
      expect(find.text('stale delayed draft'), findsNothing);
      expect(
        find.byKey(const Key('quick-content-draft-recovery')),
        findsNothing,
      );
      expect(_selectedKind(tester), LearningItemKind.word);
      final savedDraft = await store.loadQuickContentDraft();
      expect(savedDraft?.text, 'fresh early input');
      expect(savedDraft?.meanings, const ['사용자 조기 입력']);

      await tester.tap(find.byKey(const Key('quick-content-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('quick-content-unsaved-dialog')),
        findsOneWidget,
      );
      expect(find.text('fresh early input'), findsOneWidget);
    },
  );

  testWidgets('configured draft delay is honored before local persistence', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      preferences: _studyPreferences(
        const AppExperiencePreferences(quickAddDraftDelayMs: 1200),
      ),
    );
    await _pumpAndOpen(tester, store);
    await _enterRequired(
      tester,
      text: 'draft delay audit',
      meaning: '초안 간격 감사',
    );

    await tester.pump(const Duration(milliseconds: 700));
    expect(await store.loadQuickContentDraft(), isNull);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    final saved = await store.loadQuickContentDraft();
    expect(saved?.text, 'draft delay audit');
    expect(saved?.meanings, const ['초안 간격 감사']);
  });
}
