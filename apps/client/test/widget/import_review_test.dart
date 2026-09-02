import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/screens/library_screen.dart';
import 'package:sprache/src/services/recovery_checkpoint_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('import source picker fits ${width.toInt()}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 932);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            ],
            child: MaterialApp(
              theme: AppTheme.mobile,
              home: const Scaffold(body: ImportScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final practicalButton = find.byKey(
          const Key('load-tatoeba-practical-pack'),
        );
        expect(practicalButton, findsOneWidget);
        await tester.ensureVisible(practicalButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.reset();
      }
    });
  }

  testWidgets('언어팩은 저장에 필요한 핵심 확인만 먼저 보여 준다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'language-pack-friendly-word',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            subjectId: 'language:en',
            text: 'friendly',
            translations: ['친근한'],
            acceptedAnswers: ['친근한'],
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: MaterialApp(
          theme: AppTheme.mobile,
          home: const Scaffold(
            body: ImportScreen(
              languagePackMode: true,
              initialPreview: preview,
              initialFileName: 'friendly-pack.json',
              initialSha256: 'friendly-pack-sha256',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('추천 자료 추가'), findsOneWidget);
    expect(
      find.byKey(const Key('language-pack-review-summary')),
      findsOneWidget,
    );
    expect(find.text('1개를 추가할 준비가 됐어요'), findsOneWidget);
    expect(
      find.byKey(const Key('language-pack-review-details')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('import-distribution-key')), findsNothing);
    expect(find.byKey(const Key('load-tatoeba-practical-pack')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('import-commit-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1개 추가하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'distribution key restores and clears its subject and group on mobile',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      try {
        final store = MemoryStudyStore(
          preferences: StudyPreferences(
            importDistributionRules: [
              ImportDistributionRule(
                key: 'travel-core',
                subjectId: 'language:ja',
                groupName: '다음 일본 여행',
                createdAt: DateTime.utc(2026, 7, 30, 1),
                updatedAt: DateTime.utc(2026, 7, 30, 2),
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              recoveryCheckpointServiceProvider.overrideWithValue(
                _NoopRecoveryCheckpointService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.mobile,
              home: const Scaffold(body: ImportScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('import-distribution-key')),
          'Travel Core',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('import-route-subject-language:ja')),
          findsOneWidget,
        );
        final group = tester.widget<TextField>(
          find.byKey(const Key('import-distribution-group')),
        );
        expect(group.controller?.text, '다음 일본 여행');

        await tester.enterText(
          find.byKey(const Key('import-distribution-key')),
          'unknown-route',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('import-route-subject-language:en')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('import-distribution-group')),
              )
              .controller
              ?.text,
          isEmpty,
        );

        await tester.enterText(
          find.byKey(const Key('import-distribution-key')),
          'Travel Core',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('import-route-subject-language:ja')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('import-distribution-key')),
          '',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('import-route-subject-language:en')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const Key('import-distribution-group')),
              )
              .controller
              ?.text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.reset();
      }
    },
  );

  testWidgets('Excel template entry fits a 390px mobile screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: MaterialApp(
            theme: AppTheme.mobile,
            home: const Scaffold(body: ImportScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('save-excel-template')), findsOneWidget);
      expect(find.byKey(const Key('save-full-excel-template')), findsOneWidget);
      expect(find.text('간편 템플릿'), findsOneWidget);
      expect(find.text('전체 템플릿'), findsOneWidget);
      expect(find.byKey(const Key('load-tatoeba-web-pack')), findsOneWidget);
      expect(
        find.byKey(const Key('load-tatoeba-practical-pack')),
        findsOneWidget,
      );
      expect(find.textContaining('Excel, CSV'), findsOneWidget);
      expect(find.textContaining('최대 20MB'), findsOneWidget);
      expect(find.textContaining('20,000행'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final webPackButton = find.byKey(const Key('load-tatoeba-web-pack'));
      await tester.ensureVisible(webPackButton);
      await tester.tap(webPackButton);
      await tester.pump();
      expect(find.byKey(const Key('import-busy-progress')), findsOneWidget);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
        if (find
            .byKey(const Key('import-review-summary'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      expect(find.byKey(const Key('import-review-summary')), findsOneWidget);
      expect(
        find.text('tatoeba-korean-sentence-pack-2026-07-28.json'),
        findsWidgets,
      );
      expect(find.text('12'), findsWidgets);
      expect(tester.takeException(), isNull);

      final practicalButton = find.byKey(
        const Key('load-tatoeba-practical-pack'),
      );
      await tester.ensureVisible(practicalButton);
      await tester.tap(practicalButton);
      await tester.pump();
      expect(find.byKey(const Key('import-busy-progress')), findsOneWidget);
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
        if (find
            .text('tatoeba-practical-sentence-pack-2026-07-29.json')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.text('tatoeba-practical-sentence-pack-2026-07-29.json'),
        findsWidgets,
      );
      expect(find.textContaining('The meeting was cancelled.'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });

  testWidgets('import review shows field diffs and per-item decisions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final store = MemoryStudyStore();
    await store.saveCustomItems(const [
      LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      ),
    ]);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'existing-water',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'water',
            translations: ['생수'],
            acceptedAnswers: ['생수'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
        ParsedImportEntry(
          row: 3,
          item: LearningItem(
            id: 'new-axolotl',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'axolotl',
            translations: ['우파루파'],
            acceptedAnswers: ['우파루파'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
      notices: [
        ImportNotice(
          row: 3,
          message: '한자 발음을 추측하지 않았습니다. kana 또는 romaji를 추가해 주세요.',
        ),
      ],
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            recoveryCheckpointServiceProvider.overrideWithValue(
              _NoopRecoveryCheckpointService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.mobile,
            home: const Scaffold(
              body: ImportScreen(
                initialPreview: preview,
                initialFileName: 'review.csv',
                initialSha256: 'review-sha256',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('import-review-summary')), findsOneWidget);
      expect(find.byKey(const Key('import-reading-notices')), findsOneWidget);
      expect(find.text('발음 보조 확인 1개'), findsOneWidget);
      expect(find.text('기존'), findsWidgets);
      expect(find.text('가져올 값'), findsWidgets);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('import-action-3-new-axolotl-add')),
            )
            .selected,
        isTrue,
      );

      final outerList = find.byType(ListView).first;
      final replaceAction = find.byKey(
        const Key('import-action-2-existing-water-replace'),
      );
      await tester.ensureVisible(replaceAction);
      await tester.pumpAndSettle();
      await tester.tap(replaceAction);
      await tester.pump();

      await tester.drag(outerList, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('2개를 자료실에 저장해요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });

  testWidgets('blocked import row can be edited and revalidated', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final store = MemoryStudyStore();
    await store.saveCustomItems(const [
      LearningItem(
        id: 'existing-alpha',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'alpha',
        translations: ['first'],
        acceptedAnswers: ['first'],
        partOfSpeech: PartOfSpeech.noun,
      ),
      LearningItem(
        id: 'existing-beta',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'beta',
        translations: ['second'],
        acceptedAnswers: ['second'],
        partOfSpeech: PartOfSpeech.noun,
      ),
    ]);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 7,
          item: LearningItem(
            id: 'existing-alpha',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'beta',
            translations: ['second'],
            acceptedAnswers: ['second'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            recoveryCheckpointServiceProvider.overrideWithValue(
              _NoopRecoveryCheckpointService(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.mobile,
            home: const Scaffold(
              body: ImportScreen(
                initialPreview: preview,
                initialFileName: 'blocked.csv',
                initialSha256: 'blocked-sha256',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final edit = find.byKey(const Key('edit-blocked-import-7'));
      expect(edit, findsOneWidget);
      await tester.scrollUntilVisible(
        edit,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('blocked-import-id')),
        'edited-gamma',
      );
      await tester.enterText(
        find.byKey(const Key('blocked-import-text')),
        'gamma',
      );
      await tester.enterText(
        find.byKey(const Key('blocked-import-meaning')),
        'third',
      );
      await tester.tap(find.byKey(const Key('confirm-blocked-import-edit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-blocked-import-7')), findsNothing);
      expect(find.text('gamma'), findsWidgets);
      final add = tester.widget<ChoiceChip>(
        find.byKey(const Key('import-action-7-edited-gamma-add')),
      );
      expect(add.selected, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      tester.view.reset();
    }
  });

  testWidgets(
    'rejected file row can be corrected in the shared review workbench',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 3000);
      const preview = ImportPreview(
        entries: [],
        issues: [
          ImportIssue(
            row: 4,
            message: '뜻을 입력해 주세요.',
            sourceFields: {
              'type': 'word',
              'term': 'repair',
              'meaning': '',
              'language': 'en',
            },
          ),
        ],
        duplicates: [],
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              recoveryCheckpointServiceProvider.overrideWithValue(
                _NoopRecoveryCheckpointService(),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ImportScreen(
                  initialPreview: preview,
                  initialFileName: 'repair.csv',
                  initialSha256: 'repair-sha256',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('import-review-workbench')),
          findsOneWidget,
        );
        final rejected = find.byKey(const Key('import-rejected-rows'));
        await tester.tap(rejected);
        await tester.pumpAndSettle();

        final edit = find.byKey(const Key('edit-rejected-import-4'));
        expect(edit, findsOneWidget);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('rejected-import-meaning')),
          '수리하다',
        );
        await tester.tap(find.byKey(const Key('confirm-rejected-import-edit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('edit-rejected-import-4')), findsNothing);
        expect(find.text('repair'), findsWidgets);
        final repairedCard = find.byKey(const Key('import-review-entry-4'));
        expect(repairedCard, findsOneWidget);
        final action = tester.widget<ChoiceChip>(
          find
              .descendant(of: repairedCard, matching: find.byType(ChoiceChip))
              .first,
        );
        expect(action.selected, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'import review summarizes every destination and offers each result',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      const preview = ImportPreview(
        entries: [
          ParsedImportEntry(
            row: 2,
            item: LearningItem(
              id: 'destination-office',
              kind: LearningItemKind.word,
              learningLanguage: LanguageTag.english,
              text: 'brief',
              translations: ['요약'],
              acceptedAnswers: ['요약'],
              tags: ['group:업무', 'import-key:office-core'],
              partOfSpeech: PartOfSpeech.noun,
            ),
          ),
          ParsedImportEntry(
            row: 3,
            item: LearningItem(
              id: 'destination-travel',
              kind: LearningItemKind.word,
              learningLanguage: LanguageTag.japanese,
              text: '旅',
              translations: ['여행'],
              acceptedAnswers: ['여행'],
              tags: ['group:여행', 'import-key:travel-core'],
              partOfSpeech: PartOfSpeech.noun,
            ),
          ),
        ],
        issues: [],
        duplicates: [],
      );
      final store = MemoryStudyStore(
        preferences: StudyPreferences(
          importDistributionRules: [
            ImportDistributionRule(
              key: 'office-core',
              subjectId: 'language:en',
              groupName: '업무',
            ),
            ImportDistributionRule(
              key: 'travel-core',
              subjectId: 'language:ja',
              groupName: '여행',
            ),
          ],
        ),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              recoveryCheckpointServiceProvider.overrideWithValue(
                _NoopRecoveryCheckpointService(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.mobile,
              home: const Scaffold(
                body: ImportScreen(
                  initialPreview: preview,
                  initialFileName: 'destinations.xlsx',
                  initialSha256: 'destinations-sha256',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('import-destination-summary')),
          findsOneWidget,
        );
        expect(find.text('영어 > 업무'), findsOneWidget);
        expect(find.text('분배 키 office-core'), findsOneWidget);
        expect(find.text('일본어 > 여행'), findsOneWidget);
        expect(find.text('분배 키 travel-core'), findsOneWidget);

        final commit = find.byKey(const Key('import-commit-button'));
        await tester.ensureVisible(commit);
        await tester.pumpAndSettle();
        await tester.tap(commit);
        // The import stays busy while this non-dismissible destination picker
        // is open, so settle would wait on its progress indicator forever.
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byKey(const Key('import-destination-result-dialog')),
          findsOneWidget,
        );
        expect(find.text('영어 > 업무'), findsWidgets);
        expect(find.text('일본어 > 여행'), findsWidgets);
        expect(
          find.byKey(const Key('open-import-destination-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('open-import-destination-1')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.reset();
      }
    },
  );

  testWidgets('single import destination opens its subject and group', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'single-japanese-destination',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.japanese,
            text: '検証専用語',
            translations: ['검증 전용 단어'],
            acceptedAnswers: ['검증 전용 단어'],
            tags: ['group:여행', 'import-key:travel-core'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        importDistributionRules: [
          ImportDistributionRule(
            key: 'travel-core',
            subjectId: 'language:ja',
            groupName: '여행',
          ),
        ],
      ),
    );
    final router = GoRouter(
      initialLocation: '/import',
      routes: [
        GoRoute(
          path: '/import',
          builder: (context, state) => const Scaffold(
            body: ImportScreen(
              initialPreview: preview,
              initialFileName: 'travel.xlsx',
              initialSha256: 'travel-sha256',
            ),
          ),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => Scaffold(
            body: LibraryScreen(
              initialSubjectId: state.uri.queryParameters['subject'],
              initialGroup: state.uri.queryParameters['group'],
            ),
          ),
        ),
      ],
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            recoveryCheckpointServiceProvider.overrideWithValue(
              _NoopRecoveryCheckpointService(),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.mobile,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final commit = find.byKey(const Key('import-commit-button'));
      await tester.ensureVisible(commit);
      await tester.pumpAndSettle();
      await tester.tap(commit);
      await tester.pumpAndSettle();

      expect(find.text('일본어 자료실'), findsOneWidget);
      final groupChip = find.byKey(const ValueKey('mobile-learning-group-여행'));
      expect(groupChip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(groupChip).selected, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      router.dispose();
      tester.view.reset();
    }
  });
}

class _NoopRecoveryCheckpointService extends RecoveryCheckpointService {
  _NoopRecoveryCheckpointService() : super(rootResolver: _unusedCheckpointRoot);

  @override
  Future<RecoveryCheckpointReceipt> create(
    Map<String, Object?> archive, {
    required RecoveryCheckpointReason reason,
  }) async => RecoveryCheckpointReceipt(
    id: 'test-checkpoint',
    reason: reason,
    createdAt: DateTime.utc(2026, 8, 2),
    byteLength: 0,
    sha256Hex: 'test',
    customItemCount: 0,
    progressCount: 0,
    sessionCount: 0,
    path: 'memory',
  );
}

Future<String> _unusedCheckpointRoot() async => 'memory';
