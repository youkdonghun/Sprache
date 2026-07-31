import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_session_builder.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_limits.dart';
import 'package:sprache/src/import/import_reconciler.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'dataset capacity is rejected before any imported item is committed',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(
        store,
        importLimits: const ImportLimits(maxDatasetItems: 1),
      );
      await Future<void>.delayed(Duration.zero);
      const items = [
        LearningItem(
          id: 'capacity-one',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'one',
          translations: ['하나'],
          acceptedAnswers: ['하나'],
        ),
        LearningItem(
          id: 'capacity-two',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'two',
          translations: ['둘'],
          acceptedAnswers: ['둘'],
        ),
      ];

      await expectLater(
        controller.importItems(items),
        throwsA(isA<ImportLimitException>()),
      );
      expect(controller.state.customItems, isEmpty);
      expect(store.savedItems, isEmpty);
      expect(store.savedImports, isEmpty);
      controller.dispose();
    },
  );

  test(
    'resolved replacement preserves ID, increments version, and records file',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const existing = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(existing);
      const preview = ImportPreview(
        entries: [
          ParsedImportEntry(
            row: 2,
            item: LearningItem(
              id: 'foreign-water',
              kind: LearningItemKind.word,
              learningLanguage: LanguageTag.english,
              text: 'water',
              translations: ['물'],
              acceptedAnswers: ['물', '생수'],
              partOfSpeech: PartOfSpeech.noun,
            ),
          ),
        ],
        issues: [],
        duplicates: [],
      );
      final entry = controller.reviewImport(preview).entries.single;

      final result = await controller.importResolvedItems(
        [entry.resolve(ImportReviewAction.replace)],
        fileName: 'words.csv',
        sha256: '1234567890abcdef',
        rejectedRows: 0,
      );

      expect(result.replaced, 1);
      expect(result.stale, 0);
      expect(controller.state.customItems.single.id, existing.id);
      expect(
        controller.state.customItems.single.acceptedAnswers,
        contains('생수'),
      );
      expect(controller.state.customItems.single.source.contentVersion, 2);
      expect(store.savedImports.single.fileName, 'words.csv');
      expect(store.savedImports.single.importedRows, 1);
      controller.dispose();
    },
  );

  test(
    'rejects a reviewed replacement when the stored item changed meanwhile',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const existing = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await controller.upsertCustomItem(existing);
      const incoming = LearningItem(
        id: 'existing-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['생수'],
        acceptedAnswers: ['생수'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const preview = ImportPreview(
        entries: [ParsedImportEntry(row: 2, item: incoming)],
        issues: [],
        duplicates: [],
      );
      final reviewed = controller.reviewImport(preview).entries.single;
      await controller.upsertCustomItem(
        existing.copyWith(tags: const ['방금 수정']),
      );

      final result = await controller.importResolvedItems(
        [reviewed.resolve(ImportReviewAction.replace)],
        fileName: 'words.csv',
        sha256: 'abcdef1234567890',
        rejectedRows: 0,
      );

      expect(result.replaced, 0);
      expect(result.stale, 1);
      expect(controller.state.customItems.single.translations, ['물']);
      expect(controller.state.customItems.single.tags, ['방금 수정']);
      controller.dispose();
    },
  );

  test('adds a meaning to bundled content through one local overlay', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final bundled = controller.courseItems.first;
    final extraMeaning = '${bundled.primaryTranslation} 추가 뜻';
    final preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: bundled.copyWith(
            translations: [extraMeaning],
            acceptedAnswers: [extraMeaning],
          ),
        ),
      ],
      issues: const [],
      duplicates: const [],
    );
    final entry = controller.reviewImport(preview).entries.single;

    final result = await controller.importResolvedItems(
      [entry.resolve(entry.defaultAction)],
      fileName: 'bundled.xlsx',
      sha256: 'fedcba0987654321',
      rejectedRows: 0,
    );

    expect(result.replaced, 1);
    expect(
      controller.courseItems.where((item) => item.id == bundled.id),
      hasLength(1),
    );
    expect(
      controller.courseItems
          .firstWhere((item) => item.id == bundled.id)
          .translations,
      containsAll([bundled.primaryTranslation, extraMeaning]),
    );
    controller.dispose();
  });

  test(
    'imports, groups, studies, and safely re-imports the bundled web pack',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final input = File(
        'assets/content/tatoeba-korean-sentence-pack-2026-07-28.json',
      ).readAsStringSync();
      final preview = const ContentImportParser().parseJson(
        input,
        defaultLanguage: LanguageTag.english,
      );
      final firstReview = controller.reviewImport(preview);

      final imported = await controller.importResolvedItems(
        [
          for (final entry in firstReview.entries)
            entry.resolve(entry.defaultAction),
        ],
        fileName: 'tatoeba-korean-sentence-pack-2026-07-28.json',
        sha256: 'tatoeba-pack-2026-07-28-first',
        rejectedRows: 0,
      );

      expect(imported.added, 12);
      expect(imported.replaced, 0);
      expect(controller.state.customItems, hasLength(12));
      expect(
        controller.state.customItems.every(
          (item) =>
              learningGroupsOf(item).contains('Tatoeba 웹 예문') &&
              item.source.sourceId != null &&
              item.source.attribution != null,
        ),
        isTrue,
      );

      final englishWebItems = controller.courseItems
          .where((item) => item.source.name == 'Tatoeba')
          .toList(growable: false);
      final session = const StudySessionBuilder().build(
        courseId: 'ko-en',
        localDate: DateTime(2026, 7, 28),
        items: controller.courseItems,
        progress: controller.state.progress,
        plan: StudySessionPlan(
          mode: StudyMode.sentences,
          deck: StudyDeckScope.selected,
          includeWords: false,
          includeSentences: true,
          sentenceRatio: 1,
          itemLimit: 5,
          selectedItemIds: {'tatoeba-11787831', 'tatoeba-9188507'},
        ),
        personalItemIds: controller.state.customItems
            .map((item) => item.id)
            .toSet(),
      );

      expect(englishWebItems, hasLength(2));
      expect(session.items.map((item) => item.id).toSet(), {
        'tatoeba-11787831',
        'tatoeba-9188507',
      });
      controller.recordAnswer(
        item: session.items.first,
        correct: true,
        studiedAt: DateTime(2026, 7, 28, 12),
        exerciseType: 'web-pack-smoke',
      );
      expect(
        controller.state.progress[session.items.first.id]?.correctCount,
        1,
      );

      final repeatedReview = controller.reviewImport(preview);
      final repeated = await controller.importResolvedItems(
        [
          for (final entry in repeatedReview.entries)
            entry.resolve(entry.defaultAction),
        ],
        fileName: 'tatoeba-korean-sentence-pack-2026-07-28.json',
        sha256: 'tatoeba-pack-2026-07-28-repeat',
        rejectedRows: 0,
      );
      expect(repeated.added, 0);
      expect(repeated.replaced, 0);
      expect(repeated.skipped, 12);
      expect(controller.state.customItems, hasLength(12));
      controller.dispose();
    },
  );

  test(
    'basic and practical web packs import without cross-pack collisions',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const parser = ContentImportParser();
      final basic = parser.parseJson(
        File(
          'assets/content/tatoeba-korean-sentence-pack-2026-07-28.json',
        ).readAsStringSync(),
        defaultLanguage: LanguageTag.english,
      );
      final practical = parser.parseJson(
        File(
          'assets/content/tatoeba-practical-sentence-pack-2026-07-29.json',
        ).readAsStringSync(),
        defaultLanguage: LanguageTag.english,
      );

      final basicReview = controller.reviewImport(basic);
      expect(basicReview.newCount, 12);
      await controller.importResolvedItems(
        [
          for (final entry in basicReview.entries)
            entry.resolve(entry.defaultAction),
        ],
        fileName: 'tatoeba-korean-sentence-pack-2026-07-28.json',
        sha256: 'basic-web-pack',
        rejectedRows: 0,
      );

      final practicalReview = controller.reviewImport(practical);
      expect(practicalReview.newCount, 12);
      expect(practicalReview.changedCount, 0);
      expect(practicalReview.unchangedCount, 0);
      final imported = await controller.importResolvedItems(
        [
          for (final entry in practicalReview.entries)
            entry.resolve(entry.defaultAction),
        ],
        fileName: 'tatoeba-practical-sentence-pack-2026-07-29.json',
        sha256: 'practical-web-pack',
        rejectedRows: 0,
      );

      expect(imported.added, 12);
      expect(imported.replaced, 0);
      expect(controller.state.customItems, hasLength(24));
      expect(
        controller.state.customItems.map((item) => item.id).toSet(),
        hasLength(24),
      );
      expect(controller.reviewImport(practical).unchangedCount, 12);
      controller.dispose();
    },
  );
}
